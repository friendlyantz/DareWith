# Cloudinary only builds image URLs in specs; uploads go to the test storage service
Cloudinary.config.cloud_name ||= "strivo-test"
