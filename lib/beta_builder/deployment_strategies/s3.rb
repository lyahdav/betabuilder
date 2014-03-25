module BetaBuilder
  module DeploymentStrategies
    class S3 < Strategy
      def deploy_to
        "https://s3.amazonaws.com/#{@configuration.bucket}/"
      end

      def deployment_url
        File.join(deploy_to, plist_data['CFBundleVersion'], @configuration.ipa_name)
      end

      def plist_data
        plist = CFPropertyList::List.new(:file => "pkg/Payload/#{@configuration.app_name}.app/Info.plist")
        @plist_data ||= CFPropertyList.native_types(plist.value)
      end

      def manifest_url
        File.join(deploy_to, 'manifest.plist')
      end

      def prepare
        File.open("pkg/dist/manifest.plist", "w") do |io|
          io << %{
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
              <key>items</key>
              <array>
                <dict>
                  <key>assets</key>
                  <array>
                    <dict>
                      <key>kind</key>
                      <string>software-package</string>
                      <key>url</key>
                      <string>#{deployment_url}</string>
                    </dict>
                  </array>
                  <key>metadata</key>
                  <dict>
                    <key>bundle-identifier</key>
                    <string>#{plist_data['CFBundleIdentifier']}</string>
                    <key>bundle-version</key>
                    <string>#{plist_data['CFBundleVersion']}</string>
                    <key>kind</key>
                    <string>software</string>
                    <key>title</key>
                    <string>#{plist_data['CFBundleDisplayName']}</string>
                  </dict>
                </dict>
              </array>
            </dict>
            </plist>
          }
        end
        File.open("pkg/dist/index.html", "w") do |io|
          io << %{
            <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
            <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0">
            <title>#{@configuration.html_page_title}</title>
            <style type="text/css">
            body {background:#fff;margin:0;padding:0;font-family:arial,helvetica,sans-serif;text-align:center;padding:10px;color:#333;font-size:16px;}
            #container {width:300px;margin:0 auto;}
            h1 {margin:0;padding:0;font-size:14px;}
            p {font-size:13px;}
            .link {background:#ecf5ff;border-top:1px solid #fff;border:1px solid #dfebf8;margin-top:.5em;padding:.3em;}
            .link a {text-decoration:none;font-size:15px;display:block;color:#069;}
            </style>
            </head>
            <body>
            <div id="container">
            <div class="link"><a href="itms-services://?action=download-manifest&url=#{manifest_url}">Tap Here to Install<br />#{@configuration.app_name} build ##{plist_data['CFBundleVersion']}<br />On Your Device</a></div>
            <p><strong>Link didn't work?</strong><br />
            Make sure you're visiting this page on your device, not your computer.</p>
            </body>
            </html>
          }
        end
      end

      def deploy
        return if ENV['DRY_RUN']

        s3 = AWS::S3.new
        obj = s3.buckets[@configuration.bucket].objects["#{@plist_data['CFBundleVersion']}/#{@configuration.app_name}.ipa"]
        obj.write Pathname.new("pkg/dist/#{@configuration.app_name}.ipa")
        obj.acl = :public_read

        obj = s3.buckets[@configuration.bucket].objects["manifest.plist"]
        obj.write Pathname.new("pkg/dist/manifest.plist"), {
            content_type: 'text/plain',
            cache_control: 'public, max-age=0, no-cache',
        }
        obj.acl = :public_read

        obj = s3.buckets[@configuration.bucket].objects["#{@plist_data['CFBundleVersion']}/manifest.plist"]
        obj.write Pathname.new("pkg/dist/manifest.plist"), {
            content_type: 'text/plain',
            cache_control: 'public, max-age=0, no-cache',
        }
        obj.acl = :public_read

        obj = s3.buckets[@configuration.bucket].objects[@configuration.html_file]
        obj.write Pathname.new("pkg/dist/index.html")
        obj.acl = :public_read
      end
    end
  end
end
