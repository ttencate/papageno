@file:JvmName(name = "XenoCantoScraper")

package com.frozenfractal.papageno.tools

import com.frozenfractal.papageno.common.XenoCantoRecording
import org.jsoup.Jsoup
import org.jsoup.nodes.Element
import java.net.URL

const val MIN_ID = 1
const val MAX_ID = 500000

val WHITESPACE_RE = Regex("""\s+""")
val DATE_RE = Regex("""(\d{4}-\d{2}-\d{2})""")
val TIME_RE = Regex("""(\d{1,2}:\d{2})""")
val INT_RE = Regex("""(\d+)""")
val FLOAT_RE = Regex("""(\d*\.\d+|\d+\.\d*|\d+)""")

fun main(args: Array<String>) {
    val cache = WebCache("xc_pages")
    for (id in MIN_ID..MAX_ID) {
        val url = "https://www.xeno-canto.org/$id"
        val html = cache.get(url, id.toString(), 6)
        parseRecording(id, url, html)
    }
}

fun parseRecording(id: Int, url: String, html: ByteArray): XenoCantoRecording {
    val soup = Jsoup.parse(html.inputStream(), "utf-8", "https://www.xeno-canto.org/")

    val nameElement: Element? = soup.selectFirst("""h1[itemprop=name]""")
    val speciesName = nameElement?.selectText(".sci-name")?.split(WHITESPACE_RE)

    val recordingData = soup.getTable("Recording data")
    val audioFileProperties = soup.getTable("Audio file properties")
    val soundCharacteristics = soup.getTable("Sound characteristics")

    return XenoCantoRecording(
            id = id,
            url = url,

            genus = speciesName?.getOrNull(0),
            species = speciesName?.getOrNull(1),
            subspecies = speciesName?.getOrNull(2),
            englishName = nameElement?.selectText("""a[href^=/species/]"""),

            licenseUrl = soup.selectFirst("h2:contains(License)")?.nextElementSibling()?.select("a[href]")?.attr("href")?.toAbsoluteUrl(url),

            recordist = recordingData?.getCell("Recordist"),
            date = recordingData?.getCell("Date")?.extract(DATE_RE),
            time = recordingData?.getCell("Time")?.extract(TIME_RE),
            latitude = recordingData?.getCell("Latitude")?.toFloatOrNull(),
            longitude = recordingData?.getCell("Longitude")?.toFloatOrNull(),
            location = recordingData?.getCell("Location"),
            country = recordingData?.getCell("Country"),
            elevationMeters = recordingData?.getCell("Elevation")?.extract(INT_RE)?.toIntOrNull(),
            background = recordingData?.getCell("Background"),

            fileUrl = soup.selectFirst("a:contains(Download audio file)")?.attr("href")?.toAbsoluteUrl(url),
            sonogramUrl = soup.selectFirst("a:contains(Download full-length sonogram)")?.attr("href")?.toAbsoluteUrl(url),

            lengthSeconds = audioFileProperties?.getCell("Length")?.extract(FLOAT_RE)?.toFloatOrNull(),
            samplingRateHz = audioFileProperties?.getCell("Sampling rate")?.extract(INT_RE)?.toIntOrNull(),
            bitrateBps = audioFileProperties?.getCell("Bitrate of mp3")?.extract(INT_RE)?.toIntOrNull(),
            channels = audioFileProperties?.getCell("Channels")?.extract(INT_RE)?.toIntOrNull(),

            type = soundCharacteristics?.getCell("Type"),
            volume = soundCharacteristics?.getCell("Volume"),
            speed = soundCharacteristics?.getCell("Speed"),
            pitch = soundCharacteristics?.getCell("Pitch"),
            soundLength = soundCharacteristics?.getCell("Length"),
            numberOfNotes = soundCharacteristics?.getCell("Number of notes"),
            variable = soundCharacteristics?.getCell("Variable")
    )
}

fun Element.getTable(name: String): Element? =
        selectFirst("h2:contains($name) ~ table")

fun Element.getCell(name: String): String? =
        selectFirst("td:contains($name)")?.nextElementSibling()?.text()?.trim()

fun Element.selectText(cssQuery: String): String? =
        selectFirst(cssQuery)?.text()?.trim()

fun String.extract(regex: Regex): String? =
    regex.find(this)?.groupValues?.getOrNull(1)

fun String.toAbsoluteUrl(baseUrl: String): String =
        URL(URL(baseUrl), this).toString()