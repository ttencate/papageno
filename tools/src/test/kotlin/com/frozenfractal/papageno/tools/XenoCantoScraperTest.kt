package com.frozenfractal.papageno.tools

import com.frozenfractal.papageno.common.XenoCantoRecording
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import java.net.URL

class XenoCantoScraperTest {

    private fun fetchHtml(url: String): ByteArray {
        return URL(url).openConnection().getInputStream().use { inputStream ->
            inputStream.readBytes()
        }
    }

    @Test
    fun parseRecording_123456_regular() {
        val id = 123456
        val url = "https://www.xeno-canto.org/$id"
        val html = fetchHtml(url)
        assertEquals(
                parseRecording(id, url, html),
                XenoCantoRecording(
                        id = id,
                        url = url,
                        genus = "Anodorhynchus",
                        species = "hyacinthinus",
                        subspecies = null,
                        englishName = "Hyacinth Macaw",

                        licenseUrl = "https://creativecommons.org/licenses/by-nc-sa/3.0/",

                        recordist = "Eric DeFonso",
                        date = "2011-08-31",
                        time = "07:09",
                        latitude = -16.7581f,
                        longitude = -56.8764f,
                        location = "Pantanal Wildlife Center, MT",
                        country = "Brazil",
                        elevationMeters = 110,
                        background = "Guira Cuckoo (Guira guira)",

                        fileUrl = "https://www.xeno-canto.org/123456/download",
                        sonogramUrl = "https://www.xeno-canto.org/sounds/uploaded/KTLCZCRCQX/ffts/XC123456-full.png",

                        lengthSeconds = 55.2f,
                        samplingRateHz = 48000,
                        bitrateBps = 48000,
                        channels = 1,

                        type = "call",
                        volume = "both",
                        speed = "both",
                        pitch = "both",
                        soundLength = "0-3(s)",
                        numberOfNotes = "1-3",
                        variable = "yes"
                )
        )
    }

    @Test
    fun parseRecording_171618_identityUnknown() {
        val id = 171618
        val url = "https://www.xeno-canto.org/$id"
        val html = fetchHtml(url)
        assertEquals(
                parseRecording(id, url, html),
                XenoCantoRecording(
                        id = id,
                        url = url,
                        genus = null,
                        species = null,
                        subspecies = null,
                        englishName = null,

                        licenseUrl = "https://creativecommons.org/licenses/by-nc-sa/4.0/",

                        recordist = "Wimvm",
                        date = "2014-03-29",
                        time = "14:00",
                        latitude = 50.9625f,
                        longitude = 3.6504f,
                        location = "Nazareth, East Flanders, Flanders",
                        country = "Belgium",
                        elevationMeters = 100,
                        background = "none",

                        fileUrl = "https://www.xeno-canto.org/171618/download",
                        sonogramUrl = "https://www.xeno-canto.org/sounds/uploaded/JKUBVVXEVR/ffts/XC171618-full.png",

                        lengthSeconds = 4.7f,
                        samplingRateHz = 44100,
                        bitrateBps = 128000,
                        channels = 2,

                        type = "call",
                        volume = "level",
                        speed = "both",
                        pitch = "level",
                        soundLength = "3-6(s)",
                        numberOfNotes = "1-3",
                        variable = null
                )
        )
    }

    @Test
    fun parseRecording_380417_recordingRestricted() {
        val id = 380417
        val url = "https://www.xeno-canto.org/$id"
        val html = fetchHtml(url)
        assertEquals(
                parseRecording(id, url, html),
                XenoCantoRecording(
                        id = id,
                        url = url,
                        genus = "Leiothrix",
                        species = "lutea",
                        subspecies = null,
                        englishName = "Red-billed Leiothrix",

                        licenseUrl = "https://creativecommons.org/licenses/by-nc-sa/4.0/",

                        recordist = "Arnoud van den Berg",
                        date = "2017-07-16",
                        time = "14:38",
                        latitude = null,
                        longitude = null,
                        location = null,
                        country = "Netherlands",
                        elevationMeters = 3,
                        background = "Carrion Crow (Corvus corone) Eurasian Magpie (Pica pica) Eurasian Collared Dove (Streptopelia decaocto) Western Jackdaw (Coloeus monedula) House Sparrow (Passer domesticus)",

                        fileUrl = null,
                        sonogramUrl = "https://www.xeno-canto.org/sounds/uploaded/HPHJAFHVZI/ffts/XC380417-full.png",

                        lengthSeconds = 68.7f,
                        samplingRateHz = 48000,
                        bitrateBps = 158737,
                        channels = 2,

                        type = "song",
                        volume = null,
                        speed = null,
                        pitch = null,
                        soundLength = null,
                        numberOfNotes = null,
                        variable = null
                )
        )
    }

    @Test
    fun parseRecording_434476_soundscape() {
        val id = 434476
        val url = "https://www.xeno-canto.org/$id"
        val html = fetchHtml(url)
        assertEquals(
                parseRecording(id, url, html),
                XenoCantoRecording(
                        id = id,
                        url = url,
                        genus = null,
                        species = null,
                        subspecies = null,
                        englishName = null,

                        licenseUrl = "https://creativecommons.org/licenses/by-nc-nd/4.0/",

                        recordist = "Timo Tschentscher",
                        date = "2018-03-11",
                        time = "05:22",
                        latitude = 51.3905f,
                        longitude = 7.0072f,
                        location = "Essen-Werden, Ruhrgebiet, Nordrhein-Westfalen",
                        country = "Germany",
                        elevationMeters = 90,
                        background = "European Robin (Erithacus rubecula) Song Thrush (Turdus philomelos) Common Blackbird (Turdus merula)",

                        fileUrl = "https://www.xeno-canto.org/434476/download",
                        sonogramUrl = "https://www.xeno-canto.org/sounds/uploaded/PBXPSXGKLL/ffts/XC434476-full.png",

                        lengthSeconds = 113.9f,
                        samplingRateHz = 44100,
                        bitrateBps = 320000,
                        channels = 2,

                        type = "song",
                        volume = null,
                        speed = null,
                        pitch = null,
                        soundLength = null,
                        numberOfNotes = null,
                        variable = null
                )
        )
    }
}