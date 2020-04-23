/// This program processes the "simple" version of eBird Occurrences Data (eod) as can be
/// downloaded here (registration needed, but no manual approval needed):
/// https://www.gbif.org/occurrence/download?dataset_key=4fa7b334-ce0d-4e88-aaae-2e0c138d049e&has_coordinate=true&has_geospatial_issue=false&license=CC0_1_0
///
/// The full dataset is a 68 GB zip file (the site's estimate of 38 GB is too low) so it's not
/// checked into this repository. A sample of the first 10k rows is checked in as
/// `sources/eod_occurrences_sample.tsv`. In total, there are about 561M rows, which is the reason
/// why this part of the pipeline is written in the more performant Rust rather than Python.
///
/// The format is tab-separated values and there appear to be no newlines inside fields, so there
/// is no need for quoting. This means we don't need a proper CSV parser.
///
/// To run, after installing the Rust toolchain, just do:
///
///     cargo run --release
///
/// For almost 5x better performance though, let `unzip` do the unzipping:
///
///     unzip -p /path/to/eod_occurrences.zip | cargo run --release -- --input_file -

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
    /// Path to input ZIP or CSV file (- for stdin)
    #[structopt(long, default_value = "../sources/eod_occurrences.zip")]
    input_file: String,

    /// Input size in bytes, used for timing calculations only
    #[structopt(long, default_value = "271600362608")] // Default taken from the actual zip file.
    input_size: u64,

    /// Size of grid regions in degrees
    #[structopt(long, default_value = "1.0")]
    grid_size: f64,

    /// Minimum number of observations
    #[structopt(long, default_value = "10")]
    min_num_observations: u64,

    /// Minimum number of years in which a species was observed
    #[structopt(long, default_value = "3")]
    min_num_years: u32,

    /// Path to output CSV file
    #[structopt(long, default_value = "../sources/eod_regions.csv")]
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
        self.years |= 1 << (year - 2020); // If this overflows, too bad, the observation is too old anyway.
    }
}

fn main() -> std::io::Result<()> {
    let opt = Opt::from_args();

    let grid =
        if opt.input_file == "-" {
            eprintln!("Reading from stdin, assuming file size of {}", opt.input_size);
            process(&opt, &mut stdin().lock(), opt.input_size)?
        } else {
            let mut input = File::open(&opt.input_file)?;
            if opt.input_file.ends_with(".zip") {
                eprintln!("Treating {} as a ZIP file", &opt.input_file);
                let mut zip = ZipArchive::new(input)?;
                let num_files = zip.len();
                let mut file = zip.by_index(0)?;
                eprintln!("Found {} files, using first: {}", num_files, file.name());
                let file_size = file.size();
                process(&opt, &mut file, file_size)?
            } else {
                eprintln!("Treating {} as a TSV file", &opt.input_file);
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
    // There is also the species column, and the scientificName column (which includes the author
    // and date of the taxonomy). Only scientificName is part of Darwin Core:
    // https://dwc.tdwg.org/terms/#dwc:scientificName
    // Rather than parsing that, it's easier to just use the verbatimScientificName, even if it's
    // nonstandard.
    let scientific_name_index = headers.iter().position(|h| h == &"verbatimScientificName").unwrap();
    let individual_count_index = headers.iter().position(|h| h == &"individualCount").unwrap();
    let latitude_index = headers.iter().position(|h| h == &"decimalLatitude").unwrap();
    let longitude_index = headers.iter().position(|h| h == &"decimalLongitude").unwrap();
    let year_index = headers.iter().position(|h| h == &"year").unwrap();
    let license_index = headers.iter().position(|h| h == &"license").unwrap();
    let issue_index = headers.iter().position(|h| h == &"issue").unwrap();

    let mut lines_read = 0;
    let mut bytes_read = 0;
    let start_time = Instant::now();
    while { line.clear(); reader.read_line(&mut line)? > 0 } {
        lines_read += 1;
        bytes_read += line.len();
        strip_newline(&mut line);

        let fields = line.split('\t').collect::<Vec<_>>();
        let scientific_name = fields[scientific_name_index];
        let individual_count = fields[individual_count_index].parse::<u64>().unwrap_or(1);
        let latitude = match fields[latitude_index].parse::<f64>() { Ok(v) => v, _ => continue };
        let longitude = match fields[longitude_index].parse::<f64>() { Ok(v) => v, _ => continue };
        let year = match fields[year_index].parse::<u64>() { Ok(v) => v, _ => continue };
        let license = fields[license_index];
        if license != "CC0_1_0" {
            continue;
        }
        let issue = fields[issue_index];
        if issue != "" && issue != "COORDINATE_ROUNDED" {
            continue;
        }
        // eprintln!("{} {} {} {}", scientific_name, individual_count, latitude, longitude);

        let lat_lon = LatLon { lat: latitude, lon: longitude };
        grid.regions
            .entry(RegionKey::from_lat_lon(lat_lon, opt.grid_size)).or_insert_with(|| { Region::default() })
            .species
            .entry(scientific_name.to_string()).or_insert_with(|| { Counts::default() })
            .count_observation(individual_count, year);

        if lines_read % 10000 == 0 {
            let progress = bytes_read as f64 / file_size as f64;
            let elapsed_time = Instant::now() - start_time;
            let total_time = elapsed_time.div_f64(progress);
            let remaining_time = total_time - elapsed_time;
            write!(stderr(), "\r{} lines   {}/{} = {:.2}% of bytes   {}/{}   ETA {}",
                lines_read, bytes_read, file_size, progress * 100.0,
                format_duration(elapsed_time), format_duration(total_time), format_duration(remaining_time))?;
        }
    }
    write!(stderr(), "\n")?;
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
