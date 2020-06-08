/// This program processes the eBird Basic Data (EBD) and outputs the observation count per grid
/// square.
///
/// To run, first install the Rust toolchain.
///
/// Input is expected on stdin. For best performance on a multicore machine, let `pigz` do the
/// unzipping in parallel with our processing code:
///
///     cat ../sources/ebird/*.tar.part* | tar -Oxf - ebd_relApr-2020.txt.gz | pigz -cd | cargo run --release -- --ebd_file -
///
/// To run on the sample provided by eBird, which is checked into this repository but packaged
/// in a ZIP instead of a TAR file:
///
///     unzip -p sources/ebd_US-AL-101_201801_201801_relMay-2018_SAMPLE.zip ebd_US-AL-101_201801_201801_relMay-2018.txt | cargo run -- --ebd_file -

use std::collections::HashMap;
use std::fs::File;
use std::io::BufRead;
use std::io::BufReader;
use std::io::Seek;
use std::io::SeekFrom;
use std::io::stderr;
use std::io::stdin;
use std::io::Write;
use std::time::Duration;
use std::time::Instant;

use csv;
use structopt::StructOpt;
use zip::read::ZipArchive;

#[derive(StructOpt, Debug)]
#[structopt(rename_all = "snake")]
struct Opt {
    /// Path to input TAR file (- for stdin)
    #[structopt(long, default_value = "../sources/ebd.tar")]
    ebd_file: String,

    /// Uncompressed input size in bytes, used for timing calculations only. Use ebd_filesize.sh to
    /// get an estimate.
    #[structopt(long, default_value = "282555650701")]
    ebd_file_size: u64,

    /// Size of grid regions in degrees
    #[structopt(long, default_value = "1.0")]
    grid_size: f64,

    /// Minimum number of observations
    #[structopt(long, default_value = "5")]
    min_num_observations: u64,

    /// Minimum number of years in which a species was observed
    #[structopt(long, default_value = "1")]
    min_num_years: u32,

    /// Path to output CSV file
    #[structopt(long, default_value = "../sources/ebd_regions.csv")]
    output_file: String,
}

#[derive(Debug, Default)]
struct Grid {
    regions: HashMap<RegionKey, Region>,
}

#[derive(Debug)]
struct LatLon {
    lat: f64,
    lon: f64,
}

#[derive(Debug, PartialEq, Eq, Hash)]
struct RegionKey {
    lat_idx: i64,
    lon_idx: i64,
}

impl RegionKey {
    fn from_lat_lon(lat_lon: LatLon, grid_size: f64) -> RegionKey {
        return RegionKey {
            lat_idx: (lat_lon.lat / grid_size).floor() as i64,
            lon_idx: (lat_lon.lon / grid_size).floor() as i64,
        }
    }

    fn centroid(self, grid_size: f64) -> LatLon {
        return LatLon {
            lat: (self.lat_idx as f64 + 0.5) * grid_size,
            lon: (self.lon_idx as f64 + 0.5) * grid_size,
        }
    }
}

#[derive(Debug, Default)]
struct Region {
    species: HashMap<String, Counts>,
}

#[derive(Debug, Default)]
struct Counts {
    observations: u64,
    individuals: u64,
    years: u64,
}

impl Counts {
    fn count_observation(&mut self, num_individuals: u64, year: u64) {
        self.observations += 1;
        self.individuals += num_individuals;
        self.years |= 1 << (2020 - year); // If this overflows, too bad, the observation is too old anyway.
    }
}

fn main() -> std::io::Result<()> {
    let opt = Opt::from_args();

    let grid =
        if opt.ebd_file == "-" {
            eprintln!("Reading from stdin, assuming file size of {}", opt.ebd_file_size);
            process(&opt, &mut stdin().lock(), opt.ebd_file_size)?
        } else {
            let mut input = File::open(&opt.ebd_file)?;
            if opt.ebd_file.ends_with(".zip") {
                eprintln!("Treating {} as a ZIP file", &opt.ebd_file);
                let mut zip = ZipArchive::new(input)?;
                let num_files = zip.len();
                let mut file = zip.by_index(0)?;
                eprintln!("Found {} files, using first: {}", num_files, file.name());
                let file_size = file.size();
                process(&opt, &mut file, file_size)?
            } else {
                eprintln!("Treating {} as a TSV file", &opt.ebd_file);
                let file_size = input.seek(SeekFrom::End(0))?;
                input.seek(SeekFrom::Start(0))?;
                process(&opt, &mut input, file_size)?
            }
        };

    let output_file = File::create(&opt.output_file)?;
    let mut writer = csv::Writer::from_writer(output_file);
    writer.write_record(&[
        "region_id",
        "centroid_lat",
        "centroid_lon",
        "observations_by_scientific_name",
        // "individuals_by_scientific_name",
    ])?;
    let mut index = 0;
    for (key, region) in grid.regions {
        index += 1;
        let centroid = key.centroid(opt.grid_size);
        writer.write_record(&[
            index.to_string(),
            centroid.lat.to_string(),
            centroid.lon.to_string(),
            counts_to_string(region.species.iter().filter_map(|(scientific_name, counts)| {
                if counts.observations >= opt.min_num_observations &&
                    counts.years.count_ones() >= opt.min_num_years {
                    Some((scientific_name, counts.observations))
                } else {
                    None
                }
            })),
            // counts_to_string(region.species.iter()
            //                  .map(|(scientific_name, counts)| { (scientific_name, counts.individuals) })),
        ])?;
    }

    Ok(())
}

fn counts_to_string<'a, I: Iterator<Item = (&'a String, u64)>>(iter: I) -> String {
    let mut counts = iter.collect::<Vec<_>>();
    counts.sort_by_key(|&(_scientific_name, count)| { -(count as i64) });

    // Poor man's JSON generator. Why didn't I use serde?
    let mut output = String::new();
    output.push('{');
    let mut prepend_comma = false;
    for (scientific_name, count) in counts {
        if prepend_comma {
            output.push(',');
        }
        prepend_comma = true;
        output.push('"');
        output.push_str(scientific_name);
        output.push('"');
        output.push(':');
        output.push_str(&count.to_string());
    }
    output.push('}');
    output
}

fn process<F: std::io::Read>(opt: &Opt, file: &mut F, file_size: u64) -> std::io::Result<Grid> {
    let mut grid = Grid::default();
    let mut reader = BufReader::with_capacity(1024 * 1024, file);
    let mut line = String::new();

    reader.read_line(&mut line)?;
    strip_newline(&mut line);
    let headers = line.split('\t').collect::<Vec<_>>();
    let header_index = |name: &str| {
        headers.iter().position(|h| h == &name)
            .expect(&format!("No such header: {}", name))
    };
    // The scientific name of the taxon in the eBird/Clements taxonomy.
    let scientific_name_index = header_index("SCIENTIFIC NAME");
    // The count of individuals made at the time of observation. If no count was made, an 'X' is
    // used to indicate presence.
    let observation_count_index = header_index("OBSERVATION COUNT");
    // Latitude of the observation in decimal degrees.
    let latitude_index = header_index("LATITUDE");
    // Longitude of the observation in decimal degrees.
    let longitude_index = header_index("LONGITUDE");
    // Date of the observation expressed as year-month-day (YYYY-MM-DD).
    let date_index = header_index("OBSERVATION DATE");
    // The duration of the sampling event reported in minutes.
    let duration_minutes_index = header_index("DURATION MINUTES");
    // The distance traveled during the sampling event reported in kilometers.
    let distance_km_index = header_index("EFFORT DISTANCE KM");
    // The total number of observers participating the sampling event.
    let num_observers_index = header_index("NUMBER OBSERVERS");
    // A critical field that separates eBird checklist data from most other observational datasets.
    // Observers answer 'yes' to this question when they are reporting all species detected by
    // sight and by ear to the best of their ability on a given checklist (sampling event).
    // Observers answer 'no' to this question when they are only reporting a selection of species
    // from an outing, usually the highlights or unusual birds.
    let all_species_reported_index = header_index("ALL SPECIES REPORTED");
    // The status of the record within the eBird data quality process. If "Approved", the record is
    // deemed acceptable. If "Not Approved" the record has been deemed unacceptable by our review
    // processes.
    let approved_index = header_index("APPROVED");
    // "Not Reviewed" means that the record passed through our automated filters without problems,
    // that the species, date, and count were within expected levels, and that the record has
    // otherwise not been reviewed by a reviewer. "Reviewed" means that the record triggered a
    // higher-level review process, either through an automated or manual process, and that it was
    // vetted by one of our regional editors. (1 = yes; 0 = no).
    // let reviewed_index = header_index("REVIEWED");

    let mut complete_checklist_rejections = 0;
    let mut unapproved_rejections = 0;
    let mut duration_rejections = 0;
    let mut distance_rejections = 0;
    let mut observer_count_rejections = 0;
    let mut year_rejections = 0;
    let mut location_rejections = 0;
    let mut acceptations = 0;

    let mut lines_read = 0;
    let mut bytes_read = 0;
    let start_time = Instant::now();
    while { line.clear(); reader.read_line(&mut line)? > 0 } {
        if lines_read % 50000 == 0 {
            let progress = bytes_read as f64 / file_size as f64;
            let elapsed_time = Instant::now() - start_time;
            let total_time = if progress == 0.0 { elapsed_time } else { elapsed_time.div_f64(progress) };
            let remaining_time = total_time - elapsed_time;
            write!(stderr(), "\rAccepted {}/{} lines   {}/{} = {:.2}% of bytes   {}/{}   ETA {}",
                acceptations, lines_read, bytes_read, file_size, progress * 100.0,
                format_duration(elapsed_time), format_duration(total_time), format_duration(remaining_time))?;
        }

        bytes_read += line.len();
        lines_read += 1;
        strip_newline(&mut line);
        let fields = line.split('\t').collect::<Vec<_>>();

        // Apply simple recommendations by the eBird best practices document:
        // https://cornelllabofornithology.github.io/ebird-best-practices/
        // https://cornelllabofornithology.github.io/ebird-best-practices/ebird.html#ebird-detect

        // Only use complete checklists. Most important recommendation, leading to less bias.
        if fields[all_species_reported_index] != "1" {
            complete_checklist_rejections += 1;
            continue;
        }
        // "It is not advisable to use unvetted data in any kind of analysis."
        if fields[approved_index] != "1" {
            unapproved_rejections += 1;
            continue;
        }
        // Use only observations of at most 5 hours long.
        if fields[duration_minutes_index].parse::<u64>().unwrap_or(0) > 5 * 60 {
            duration_rejections += 1;
            continue;
        }
        // Use only observations during which at most 5 kilometers were travelled.
        if fields[distance_km_index].parse::<f64>().unwrap_or(0.0) > 5.0 {
            distance_rejections += 1;
            continue;
        }
        // Use only observations with at most 10 participants.
        if fields[num_observers_index].parse::<u64>().unwrap_or(1) > 10 {
            observer_count_rejections += 1;
            continue;
        }
        let year = match fields[date_index][0..4].parse::<u64>() {
            Ok(v) => v,
            _ => { year_rejections += 1; continue }
        };
        // Use only observations in the past 10 years.
        if year < 2010 || year >= 2020 {
            year_rejections += 1;
            continue;
        }
        let latitude = match fields[latitude_index].parse::<f64>() {
            Ok(v) => v,
            _ => { location_rejections += 1; continue }
        };
        let longitude = match fields[longitude_index].parse::<f64>() {
            Ok(v) => v,
            _ => { location_rejections += 1; continue }
        };
        acceptations += 1;

        let scientific_name = fields[scientific_name_index];
        let individual_count = fields[observation_count_index].parse::<u64>().unwrap_or(1);

        let lat_lon = LatLon { lat: latitude, lon: longitude };
        grid.regions
            .entry(RegionKey::from_lat_lon(lat_lon, opt.grid_size)).or_insert_with(|| { Region::default() })
            .species
            .entry(scientific_name.to_string()).or_insert_with(|| { Counts::default() })
            .count_observation(individual_count, year);
    }
    write!(stderr(), "\n")?;
    let print_stat = |name: &str, stat: u64| {
        writeln!(stderr(), "{:33} {:9}", name, stat).unwrap();
    };
    print_stat("Total bytes processed", bytes_read);
    print_stat("Total lines processed", lines_read);
    print_stat("Accepted", acceptations);
    print_stat("Rejected (incomplete checklist)", complete_checklist_rejections);
    print_stat("Rejected (not approved)", unapproved_rejections);
    print_stat("Rejected (duration too large)", duration_rejections);
    print_stat("Rejected (distance too large)", distance_rejections);
    print_stat("Rejected (too many observers)", observer_count_rejections);
    print_stat("Rejected (too old)", year_rejections);
    print_stat("Rejected (location unparseable)", location_rejections);
    Ok(grid)
}

fn strip_newline(line: &mut String) {
    if line.ends_with('\n') {
        line.pop();
        if line.ends_with('\r') {
            line.pop();
        }
    }
}

fn format_duration(d: Duration) -> String {
    let mut s = d.as_secs();
    let hours = s / 3600;
    s %= 3600;
    let minutes = s / 60;
    s %= 60;
    let seconds = s;
    format!("{}:{:02}:{:02}", hours, minutes, seconds)
}
