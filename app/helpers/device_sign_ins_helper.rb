module DeviceSignInsHelper
  # Dark modules on white whatever the theme, so phone cameras can read it
  def device_sign_in_qr_code(device_sign_in)
    url = new_device_sign_in_approval_url(code: device_sign_in.code)
    svg = RQRCode::QRCode.new(url).as_svg(use_path: true, viewbox: true, svg_attributes: {class: "size-full", role: "img", "aria-label": "QR code"})

    tag.div(svg.html_safe, class: "size-48 rounded-box bg-white p-3")
  end

  def spaced_code(code)
    code.chars.each_slice(3).map(&:join).join(" ")
  end
end
