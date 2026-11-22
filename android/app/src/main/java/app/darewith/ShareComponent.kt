package app.darewith

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.util.Base64
import androidx.core.content.FileProvider
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import org.json.JSONObject
import java.io.File

// Opens Android's share sheet for the site's share buttons (app/javascript/native_share.js),
// since the WebView has no navigator.share. Shares text, or an image (a progress card) with its text.
class ShareComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {
    private val fragment get() = delegate.destination.fragment

    override fun onReceive(message: Message) {
        if (message.event != "share") return

        val data = JSONObject(message.jsonData)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, data.getString("text"))
            data.optString("title").takeIf { it.isNotEmpty() }?.let { putExtra(Intent.EXTRA_TITLE, it) }

            data.optString("image").takeIf { it.isNotEmpty() }?.let { image ->
                val uri = saveImage(image, data.getString("fileName"))
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = ClipData.newRawUri(null, uri) // the share sheet's preview
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        }

        fragment.startActivity(Intent.createChooser(intent, null))
    }

    // The image arrives as a data URL; apps read it from our cache through the FileProvider (res/xml/file_paths.xml)
    private fun saveImage(dataUrl: String, fileName: String): Uri {
        val context = fragment.requireContext()
        val file = File(context.cacheDir, "shared/$fileName").apply {
            parentFile?.mkdirs()
            writeBytes(Base64.decode(dataUrl.substringAfter(","), Base64.DEFAULT))
        }
        return FileProvider.getUriForFile(context, "${context.packageName}.files", file)
    }
}
