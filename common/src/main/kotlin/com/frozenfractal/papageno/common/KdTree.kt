package com.frozenfractal.papageno.common

class KdTreeParams(
        val minRecordingsPerNode: Int,
        val maxLevel: Int
)

/**
 * A K-d tree that partitions the globe.
 * Longitude (-180..180) is mapped to x, latitude (-90..90) is mapped to y.
 * The first split happens based on x coordinate.
 * We keep splitting nodes until we'd go below the maximum number of recordings per node.
 */
class KdTree private constructor (private val root: Node) {
    companion object {
        fun fromRecordings(recordings: List<XenoCantoRecording>, params: KdTreeParams): KdTree =
                KdTree(createNode(recordings, Box(-180f to 180f, -90f to 90f, 0), params))

        private fun createNode(recordings: List<XenoCantoRecording>, box: Box, params: KdTreeParams): Node {
            if (recordings.size < params.minRecordingsPerNode || box.level >= params.maxLevel) {
                return Node.LeafNode(recordings = recordings)
            } else {
                val (leftBox, rightBox) = box.split()
                val leftRecordings = mutableListOf<XenoCantoRecording>()
                val rightRecordings = mutableListOf<XenoCantoRecording>()
                for (recording in recordings) {
                    if (recording in leftBox) {
                        leftRecordings.add(recording)
                    } else {
                        rightRecordings.add(recording)
                    }
                }
                return Node.InternalNode(
                        left = createNode(leftRecordings, leftBox, params),
                        right = createNode(rightRecordings, rightBox, params))
            }
        }
    }

    fun serialize(): ByteArray {
        val numNodes = root.countNodes()
        val numLeafNodes = root.countLeafNodes()
        // One bit for the node type, 8 bits to store the count of each leaf node
        return ByteArray((numNodes + 7) / 8 + numLeafNodes)
    }
}

private sealed class Node {
    abstract fun countNodes(): Int
    abstract fun countLeafNodes(): Int

    class InternalNode(val left: Node, val right: Node): Node() {
        override fun countNodes() =
                1 + left.countNodes() + right.countNodes()
        override fun countLeafNodes() =
                left.countLeafNodes() + right.countLeafNodes()
    }

    class LeafNode(val recordings: List<XenoCantoRecording>): Node() {
        override fun countNodes() = 1
        override fun countLeafNodes() = 1
    }
}

private class Box(val longitudes: FloatRange, val latitudes: FloatRange, val level: Int) {

    operator fun contains(recording: XenoCantoRecording) =
        recording.longitude!! in longitudes && recording.latitude!! in latitudes

    fun split(): Pair<Box, Box> {
        val nextLevel = level + 1
        return if (level % 2 == 0) {
            val (leftLon, rightLon) = longitudes.split()
            Pair(Box(leftLon, longitudes, nextLevel), Box(rightLon, longitudes, nextLevel))
        } else {
            val (leftLat, rightLat) = latitudes.split()
            Pair(Box(longitudes, leftLat, nextLevel), Box(longitudes, rightLat, nextLevel))
        }
    }
}

private class FloatRange(val min: Float, val max: Float) {
    operator fun contains(f: Float) =
            min <= f && f < max

    fun split(): Pair<FloatRange, FloatRange> {
        val mid = (min + max) / 2
        return Pair(min to mid, mid to max)
    }
}

private infix fun Float.to(end: Float): FloatRange =
        FloatRange(this, end)