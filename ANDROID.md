# ZEEP Breathe บน Android

Android build บนเครื่อง Windows นี้ได้เลย ไม่ต้องใช้บริการคลาวด์

## ทางที่ 1: ส่งไฟล์ APK ให้ผู้ทดสอบโดยตรง (เร็วที่สุด)

```
cd mobile
flutter build apk --release
```
ได้ไฟล์ `build/app/outputs/flutter-apk/app-release.apk` (~20 MB)
ส่งไฟล์ทาง LINE / Google Drive / อีเมล แล้วผู้ทดสอบกดเปิดไฟล์บนมือถือ
(ครั้งแรกต้องอนุญาต "ติดตั้งแอปจากแหล่งที่ไม่รู้จัก")

หรือต่อมือถือด้วยสาย USB (เปิด USB debugging) แล้วสั่ง `flutter install`

## ทางที่ 2: Google Play Internal testing (เทียบเท่า TestFlight)

ผู้ทดสอบติดตั้งและอัปเดตผ่าน Play Store ได้ตามปกติ

1. สมัคร **Google Play Console** (จ่ายครั้งเดียว 25 USD): https://play.google.com/console
   บัญชีส่วนตัวที่สร้างใหม่ต้องผ่าน closed testing (12 คน × 14 วัน) ก่อนขึ้น production
   แต่ **Internal testing ใช้ได้ทันที** (สูงสุด 100 คน)
2. **สร้าง upload key** (ทำครั้งเดียว และเก็บไฟล์กับรหัสผ่านให้ดี):
   ```
   keytool -genkey -v -keystore mobile/android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   แล้วสร้างไฟล์ `mobile/android/key.properties`:
   ```
   storePassword=<รหัสที่ตั้ง>
   keyPassword=<รหัสที่ตั้ง>
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```
   ทั้งสองไฟล์อยู่ใน `.gitignore` แล้ว ห้าม commit
3. Build ไฟล์สำหรับ Play:
   ```
   flutter build appbundle --release
   ```
   ได้ `build/app/outputs/bundle/release/app-release.aab`
4. Play Console → Create app → ตั้งชื่อ `ZEEP Breathe`
   → Testing → **Internal testing** → Create new release → อัปโหลดไฟล์ `.aab`
   (ครั้งแรกให้กดยอมรับ Play App Signing)
5. แท็บ Testers → สร้างรายชื่ออีเมล (Gmail) → คัดลอกลิงก์เชิญส่งให้ผู้ทดสอบ
6. ก่อนปล่อยครั้งแรก Play Console จะให้กรอก App content ให้ครบ (Privacy policy,
   Data safety: แอปนี้ไม่เก็บข้อมูลผู้ใช้, กลุ่มอายุ, โฆษณา: ไม่มี)

ทุกครั้งที่อัปเดต ให้เพิ่มเลข build ใน `pubspec.yaml` ก่อน เช่น `version: 1.0.0+2`

Application ID: `com.pillarsnova.zeepbreathe` (เปลี่ยนไม่ได้หลังอัปโหลดขึ้น Play ครั้งแรก)

## หมายเหตุเครื่องนี้

ไดรฟ์ C: เหลือพื้นที่น้อย จึงติดตั้ง Android NDK 28.2 ไว้ที่ `D:\Android\ndk\28.2.13676358`
แล้วลิงก์ (junction) เข้าไปที่ `%LOCALAPPDATA%\Android\sdk\ndk\28.2.13676358`
