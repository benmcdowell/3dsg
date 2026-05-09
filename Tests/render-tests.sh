#!/bin/zsh

cd ..

swift run 3dsg --device iphone-17-pro     --rotation 0,0,0 --screen ./Tests/Resources/iphone-17-pro-portrait.png      --output ./Tests/Output/render-iphone-17-pro-portrait.png      --size 2400x2400
swift run 3dsg --device iphone-17-pro     --rotation 0,0,0 --screen ./Tests/Resources/iphone-17-pro-landscape.png     --output ./Tests/Output/render-iphone-17-pro-landscape.png     --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --rotation 0,0,0 --screen ./Tests/Resources/iphone-17-pro-max-portrait.png  --output ./Tests/Output/render-iphone-17-pro-max-portrait.png  --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --rotation 0,0,0 --screen ./Tests/Resources/iphone-17-pro-max-landscape.png --output ./Tests/Output/render-iphone-17-pro-max-landscape.png --size 2400x2400
swift run 3dsg --device ipad-pro-13-inch  --rotation 0,0,0 --screen ./Tests/Resources/ipad-pro-13-inch-portrait.png   --output ./Tests/Output/render-ipad-pro-13-inch-portrait.png   --size 2400x2400
swift run 3dsg --device ipad-pro-13-inch  --rotation 0,0,0 --screen ./Tests/Resources/ipad-pro-13-inch-landscape.png  --output ./Tests/Output/render-ipad-pro-13-inch-landscape.png  --size 2400x2400

swift run 3dsg --device iphone-17-pro     --rotation 0,45,0 --screen ./Tests/Resources/iphone-17-pro-portrait.png      --output ./Tests/Output/render-0,45,0-iphone-17-pro-portrait.png      --size 2400x2400
swift run 3dsg --device iphone-17-pro     --rotation 0,45,0 --screen ./Tests/Resources/iphone-17-pro-landscape.png     --output ./Tests/Output/render-0,45,0-iphone-17-pro-landscape.png     --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --rotation 0,45,0 --screen ./Tests/Resources/iphone-17-pro-max-portrait.png  --output ./Tests/Output/render-0,45,0-iphone-17-pro-max-portrait.png  --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --rotation 0,45,0 --screen ./Tests/Resources/iphone-17-pro-max-landscape.png --output ./Tests/Output/render-0,45,0-iphone-17-pro-max-landscape.png --size 2400x2400
swift run 3dsg --device ipad-pro-13-inch  --rotation 0,45,0 --screen ./Tests/Resources/ipad-pro-13-inch-portrait.png   --output ./Tests/Output/render-0,45,0-ipad-pro-13-inch-portrait.png   --size 2400x2400
swift run 3dsg --device ipad-pro-13-inch  --rotation 0,45,0 --screen ./Tests/Resources/ipad-pro-13-inch-landscape.png  --output ./Tests/Output/render-0,45,0-ipad-pro-13-inch-landscape.png  --size 2400x2400

swift run 3dsg --device iphone-17-pro     --rotation 45,0,0 --screen ./Tests/Resources/iphone-17-pro-portrait.png      --output ./Tests/Output/render-45,0,0-iphone-17-pro-portrait.png      --size 2400x2400
swift run 3dsg --device iphone-17-pro     --rotation 45,0,0 --screen ./Tests/Resources/iphone-17-pro-landscape.png     --output ./Tests/Output/render-45,0,0-iphone-17-pro-landscape.png     --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --rotation 45,0,0 --screen ./Tests/Resources/iphone-17-pro-max-portrait.png  --output ./Tests/Output/render-45,0,0-iphone-17-pro-max-portrait.png  --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --rotation 45,0,0 --screen ./Tests/Resources/iphone-17-pro-max-landscape.png --output ./Tests/Output/render-45,0,0-iphone-17-pro-max-landscape.png --size 2400x2400
swift run 3dsg --device ipad-pro-13-inch  --rotation 45,0,0 --screen ./Tests/Resources/ipad-pro-13-inch-portrait.png   --output ./Tests/Output/render-45,0,0-ipad-pro-13-inch-portrait.png   --size 2400x2400
swift run 3dsg --device ipad-pro-13-inch  --rotation 45,0,0 --screen ./Tests/Resources/ipad-pro-13-inch-landscape.png  --output ./Tests/Output/render-45,0,0-ipad-pro-13-inch-landscape.png  --size 2400x2400

swift run 3dsg --device iphone-17-pro     --rotation 0,0,45 --screen ./Tests/Resources/iphone-17-pro-portrait.png      --output ./Tests/Output/render-0,0,45-iphone-17-pro-portrait.png      --size 2400x2400
swift run 3dsg --device iphone-17-pro     --rotation 0,0,45 --screen ./Tests/Resources/iphone-17-pro-landscape.png     --output ./Tests/Output/render-0,0,45-iphone-17-pro-landscape.png     --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --rotation 0,0,45 --screen ./Tests/Resources/iphone-17-pro-max-portrait.png  --output ./Tests/Output/render-0,0,45-iphone-17-pro-max-portrait.png  --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --rotation 0,0,45 --screen ./Tests/Resources/iphone-17-pro-max-landscape.png --output ./Tests/Output/render-0,0,45-iphone-17-pro-max-landscape.png --size 2400x2400
swift run 3dsg --device ipad-pro-13-inch  --rotation 0,0,45 --screen ./Tests/Resources/ipad-pro-13-inch-portrait.png   --output ./Tests/Output/render-0,0,45-ipad-pro-13-inch-portrait.png   --size 2400x2400
swift run 3dsg --device ipad-pro-13-inch  --rotation 0,0,45 --screen ./Tests/Resources/ipad-pro-13-inch-landscape.png  --output ./Tests/Output/render-0,0,45-ipad-pro-13-inch-landscape.png  --size 2400x2400

swift run 3dsg --device iphone-17-pro     --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-portrait.png      --output ./Tests/Output/render-45,25,25-iphone-17-pro-portrait.png      --size 2400x2400
swift run 3dsg --device iphone-17-pro     --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-landscape.png     --output ./Tests/Output/render-45,25,25-iphone-17-pro-landscape.png     --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-max-portrait.png  --output ./Tests/Output/render-45,25,25-iphone-17-pro-max-portrait.png  --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-max-landscape.png --output ./Tests/Output/render-45,25,25-iphone-17-pro-max-landscape.png --size 2400x2400
swift run 3dsg --device ipad-pro-13-inch  --rotation 45,25,25 --screen ./Tests/Resources/ipad-pro-13-inch-portrait.png   --output ./Tests/Output/render-45,25,25-ipad-pro-13-inch-portrait.png   --size 2400x2400
swift run 3dsg --device ipad-pro-13-inch  --rotation 45,25,25 --screen ./Tests/Resources/ipad-pro-13-inch-landscape.png  --output ./Tests/Output/render-45,25,25-ipad-pro-13-inch-landscape.png  --size 2400x2400

swift run 3dsg --device iphone-17-pro     --color cosmic-orange --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-portrait.png      --output ./Tests/Output/render-45,25,25-cosmic-orange-iphone-17-pro-portrait.png      --size 2400x2400
swift run 3dsg --device iphone-17-pro     --color cosmic-orange --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-landscape.png     --output ./Tests/Output/render-45,25,25-cosmic-orange-iphone-17-pro-landscape.png     --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --color cosmic-orange --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-max-portrait.png  --output ./Tests/Output/render-45,25,25-cosmic-orange-iphone-17-pro-max-portrait.png  --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --color cosmic-orange --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-max-landscape.png --output ./Tests/Output/render-45,25,25-cosmic-orange-iphone-17-pro-max-landscape.png --size 2400x2400

swift run 3dsg --device iphone-17-pro     --color deep-blue --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-portrait.png      --output ./Tests/Output/render-45,25,25-deep-blue-iphone-17-pro-portrait.png      --size 2400x2400
swift run 3dsg --device iphone-17-pro     --color deep-blue --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-landscape.png     --output ./Tests/Output/render-45,25,25-deep-blue-iphone-17-pro-landscape.png     --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --color deep-blue --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-max-portrait.png  --output ./Tests/Output/render-45,25,25-deep-blue-iphone-17-pro-max-portrait.png  --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --color deep-blue --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-max-landscape.png --output ./Tests/Output/render-45,25,25-deep-blue-iphone-17-pro-max-landscape.png --size 2400x2400

swift run 3dsg --device iphone-17-pro     --color silver --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-portrait.png      --output ./Tests/Output/render-45,25,25-silver-iphone-17-pro-portrait.png      --size 2400x2400
swift run 3dsg --device iphone-17-pro     --color silver --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-landscape.png     --output ./Tests/Output/render-45,25,25-silver-iphone-17-pro-landscape.png     --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --color silver --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-max-portrait.png  --output ./Tests/Output/render-45,25,25-silver-iphone-17-pro-max-portrait.png  --size 2400x2400
swift run 3dsg --device iphone-17-pro-max --color silver --rotation 45,25,25 --screen ./Tests/Resources/iphone-17-pro-max-landscape.png --output ./Tests/Output/render-45,25,25-silver-iphone-17-pro-max-landscape.png --size 2400x2400
