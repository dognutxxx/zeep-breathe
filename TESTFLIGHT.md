# ส่ง ZEEP Breathe ขึ้น TestFlight (ไม่ต้องมี Mac)

Build บน Mac ในคลาวด์ของ **Codemagic** (แพ็กเกจฟรีมีเวลา build บน macOS ให้ทุกเดือน)
ไฟล์ตั้งค่าอยู่ที่ [codemagic.yaml](codemagic.yaml) แล้ว

## สิ่งที่ต้องมี

- บัญชี **Apple Developer Program** (99 USD/ปี) ที่ https://developer.apple.com/programs/
- โค้ดอยู่บน Git hosting (GitHub / GitLab / Bitbucket) ที่ใช้โฟลเดอร์ `mobile/` นี้เป็น root ของ repo
- บัญชี Codemagic ที่ https://codemagic.io (ล็อกอินด้วย GitHub ได้)

## ขั้นตอน (ทำครั้งเดียว)

1. **สร้าง Bundle ID**: developer.apple.com → Certificates, IDs & Profiles → Identifiers → `+`
   → App IDs → ใส่ `com.pillarsnova.zeepBreathe`
   (ถ้าต้องการชื่ออื่น ให้แก้ใน `codemagic.yaml` และ `PRODUCT_BUNDLE_IDENTIFIER` ใน
   `ios/Runner.xcodeproj/project.pbxproj` ให้ตรงกัน)
2. **สร้างแอปใน App Store Connect**: https://appstoreconnect.apple.com → Apps → `+` New App
   → Platform iOS, ชื่อ `ZEEP Breathe`, เลือก Bundle ID จากข้อ 1, SKU อะไรก็ได้
   → เปิด **App Information** แล้วจด **Apple ID** (ตัวเลข 10 หลัก)
3. **สร้าง API key**: App Store Connect → Users and Access → Integrations → App Store Connect API
   → `+` สิทธิ์ **App Manager** → ดาวน์โหลดไฟล์ `.p8` (โหลดได้ครั้งเดียว) และจด Issuer ID กับ Key ID
4. **เชื่อม Codemagic**: Codemagic → Team settings → Integrations → Developer Portal → Connect
   → ใส่ Issuer ID, Key ID, ไฟล์ `.p8` และ **ตั้งชื่อ key** (เช่น `ZEEP App Store Connect key`)
5. **Code signing**: Codemagic → Team settings → codemagic.yaml settings → Code signing identities
   → iOS certificates → Generate certificate (ประเภท Apple Distribution)
   แล้วที่ iOS provisioning profiles → Fetch profiles สำหรับ `com.pillarsnova.zeepBreathe` (App Store)
6. **แก้ placeholder 2 จุด** ใน `codemagic.yaml`:
   - `app_store_connect:` → ชื่อ key จากข้อ 4
   - `APP_STORE_APPLE_ID:` → ตัวเลขจากข้อ 2
7. Push ขึ้น GitHub → Codemagic → **Start new build** → เลือก workflow **iOS → TestFlight**
   → build และอัปโหลดให้เอง (~15–25 นาที)

## หลังอัปโหลด

- รอ Apple ประมวลผล build ~5–30 นาที (มีอีเมลแจ้ง)
- **ทดสอบภายในทีม** (สูงสุด 100 คน ไม่ต้องรอรีวิว): App Store Connect → TestFlight
  → Internal Testing → `+` เพิ่มคนที่อยู่ใน Users and Access
- **ทดสอบภายนอก** (สูงสุด 10,000 คน): สร้าง External group → ต้องผ่าน Beta App Review ครั้งแรก (~1 วัน)
  ต้องกรอก Test Information และลิงก์ Privacy Policy
- ผู้ทดสอบติดตั้งแอป **TestFlight** จาก App Store แล้วกดรับคำเชิญ

ไม่ต้องตอบคำถามเรื่อง encryption ทุกครั้ง เพราะ `Info.plist` ตั้ง
`ITSAppUsesNonExemptEncryption = false` ไว้แล้ว (แอปไม่ใช้การเข้ารหัสของตัวเอง)

## ทางเลือก: ถ้ามี Mac

```
cd mobile
flutter pub get
open ios/Runner.xcworkspace   # Signing & Capabilities → เลือก Team
flutter build ipa
```
แล้วอัปโหลด `build/ios/ipa/*.ipa` ด้วยแอป **Transporter** หรือ Xcode → Organizer → Distribute App

## ทดสอบบนเครื่องนี้ (Windows)

```
flutter test                                        # unit tests ของ breathing engine
flutter test tool/screens_test.dart --update-goldens  # เรนเดอร์ภาพหน้าจอขนาด iPhone ไว้ที่ tool/screens/
python tool/render_audio.py                         # สร้างไฟล์เพลงพื้นหลังใหม่
```
