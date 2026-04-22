# Deal Flutter App Completion TODO

## Progress Tracking for Backend-Aligned Flutter App

### [x] 1. Setup Environment
- [x] Create deal/.env with BASE_URL
- [ ] flutter pub get

### [x] 2. Fix Core Files
- [x] Fix auth_provider.dart syntax errors
- [x] Cleanup README.md (remove git junk)

### [x] 3. Complete Auth Flow
- [x] Create/Fix login_screen.dart (form + login call)
- [x] Update main.dart: proper imports, MaterialApp.router or routes, logout button

### [ ] 4. Product Features
- [ ] create_product_screen.dart: impl image upload (/upload), real geolocator + /geocode/reverse
- [ ] Add my_products screen/tab (fetch /product/my-products)

### [ ] 5. Chat Features
- [ ] Create chat_provider.dart (fetch /chat, socket)
- [ ] Fix chat_list_screen.dart
- [ ] Create chat_room_screen.dart

### [ ] 6. Profile & Navigation
- [ ] Fix profile_screen.dart (/user/me, update profile)
- [ ] Add bottom navigation (Home, MyProducts, Create, Chats, Profile)

### [ ] 7. Polish & Test
- [ ] Ensure all models (product_model, message_model)
- [ ] Test full flow: register/login/post product/chat
- [ ] Update README with screenshots/commands

**Next step after each: Update this TODO.md with [x] completed.**

Current status: Starting implementation.

