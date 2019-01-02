@file:JvmName(name = "Processor")

package com.frozenfractal.papageno.tools

import com.frozenfractal.papageno.common.KdTree
import com.frozenfractal.papageno.common.KdTreeParams
import com.frozenfractal.papageno.common.XenoCantoRecording
import mu.KotlinLogging

fun XenoCantoRecording.isUsable() =
        genus != null && species != null

fun main(args: Array<String>) {
    val db = openDatabase(true)

    logger.info("Loading recordings from database...")
    val recordings = db
            .select(XenoCantoRecording::class)
            .get()
            .filter(XenoCantoRecording::isUsable)
            .toList()
    logger.info("${recordings.size} usable recordings found")

    logger.info("Grouping recordings by species...")
    val recordingsBySpeciesName = recordings
            .groupBy(XenoCantoRecording::speciesName)
            .filter { it.value.size >= 20 }
    logger.info("${recordingsBySpeciesName.size} species found with sufficient number of recordings")

    logger.info("Constructing k-d trees...")
    val params = KdTreeParams(minRecordingsPerNode = 10, maxLevel = 8)
    var totalSize = 0
    for (entry in recordingsBySpeciesName) {
        val tree = KdTree.fromRecordings(entry.value.filter(XenoCantoRecording::hasLocation), params)
        totalSize += tree.serialize().size
    }
    logger.info("Total k-d tree size: $totalSize")
}

private val logger = KotlinLogging.logger {}