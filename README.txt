مدرستي - طريقة بناء التطبيق بدون تثبيت أي برنامج

1) سجّل حساباً مجانياً في github.com
2) اضغط + (أعلى اليمين) ثم New repository ، الاسم: madrasati ، اختر Public ، ثم Create repository
3) اضغط على الرابط: uploading an existing file
4) افتح مجلد madrasati (بعد فك الضغط) وحدد كل ما بداخله واسحبه إلى صفحة GitHub ، ثم Commit changes
5) تأكد أن مجلد .github ظهر في الصفحة. إذا لم يظهر:
   Add file > Create new file ، الاسم: .github/workflows/build.yml
   والصق فيه محتوى الملف build.yml (افتحه بالمفكرة Notepad) ثم Commit changes
6) افتح تبويب Actions وانتظر حتى تصبح العلامة خضراء (حوالي 10 دقائق)
7) افتح البناء الأخضر، وفي الأسفل تحت Artifacts اضغط madrasati-apk لتنزيله
8) فك الضغط، أرسل app-release.apk إلى هاتفك (واتساب أو كابل) وثبّته
   (إذا طلب الهاتف: اسمح بتثبيت التطبيقات من مصادر غير معروفة)

أي تعديل لاحق: ارفع الملف المعدّل بنفس الطريقة، وGitHub يبني نسخة جديدة تلقائياً.
