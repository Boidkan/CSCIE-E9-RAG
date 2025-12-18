### System Requirements
• iOS: iOS 26 or later
• iPadOS: iPadOS 26 or later
• macOS: macOS 26 (Tahoe)

### Hardware Requirements
* iPhone: A17 chip or higher
* Mac: M-series chip

### Apple Intelligence
This must be toggled on:
`System Settings → Apple Intelligence & Siri → Apple Intelligence`

### Open the app
Inside the root repo folder double tap/click on RAG.xcodeproj

<img width="246" height="165" alt="Screenshot 2025-12-17 at 10 43 35 PM" src="https://github.com/user-attachments/assets/56e418ac-bb8f-4c62-a56a-22e74323fd2d" />


### Building The App

#### If you only want to run it on a simulator then you do not need to create an Apple Developer Account:

From the top middle select a simulator as a run destination:

<img width="410" height="1090" alt="Screenshot 2025-12-17 at 10 46 14 PM" src="https://github.com/user-attachments/assets/a2fc8cb6-fe27-4832-a00d-3657759109d5" />

Once selected either hit the play button in the top left or use `command + r`.

#### To run on a physical device such as your personal iPhone

* Create an Apple Developer account if you do not have one https://developer.apple.com/account
* Login to your Apple Developer account in Xcode
  `Xcode -> Settings -> Apple Account -> Add Apple Account`
* Update your code signing team in the RAG app:
  * Select the app project from the navigation menu on the left
  * Select Code Signing & Capabilities
  * Next to "Team" select your account from the dropdown
<img width="1770" height="349" alt="Screenshot 2025-12-17 at 10 57 17 PM" src="https://github.com/user-attachments/assets/0d84a9bb-3219-4952-8a8a-b02900f1c585" />

