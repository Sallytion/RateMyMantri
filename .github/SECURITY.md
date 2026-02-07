# Security Policy

## Sensitive Files

The following files contain API keys and sensitive configuration data and **MUST NOT be committed to version control**:

### Always Gitignored
- `android/app/google-services.json` - Firebase Android configuration
- `ios/Runner/GoogleService-Info.plist` - Firebase iOS configuration
- `lib/firebase_options.dart` - Generated Firebase SDK options
- `send_notification.ps1` - FCM notification scripts with OAuth tokens
- Any `.env` files containing API keys

### Template Files (Safe to Commit)
- `lib/firebase_options.dart.template` - Template showing structure only

## API Key Management

### Firebase API Keys
All Firebase API keys in this project are **restricted** in Google Cloud Console to:
- Specific bundle IDs/package names
- Specific Firebase services only
- Specific SHA-1 fingerprints

### Setting Up Your Environment

1. **Never** copy API keys from screenshots or documentation
2. Generate your own Firebase project
3. Use FlutterFire CLI to configure:
   ```bash
   flutterfire configure --project=your-project-id
   ```
4. Download `google-services.json` from YOUR Firebase Console
5. Configure API restrictions in Google Cloud Console

## Reporting Security Issues

If you discover a security vulnerability:
1. **DO NOT** open a public issue
2. Email: [your-security-email@example.com]
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Security Checklist for Contributors

Before committing:
- [ ] Run `git status` to check for untracked sensitive files
- [ ] Verify `.gitignore` is properly configured
- [ ] Ensure no API keys in code comments
- [ ] No hardcoded secrets or credentials
- [ ] All config files use templates or environment variables

## API Key Exposure Response

If API keys are accidentally committed:
1. **Immediately** revoke the exposed keys in Google Cloud Console
2. Generate new keys with proper restrictions
3. Update `.gitignore` to prevent recurrence
4. Use `git filter-branch` or BFG Repo-Cleaner to remove from history
5. Force push to remote (coordinate with team first)

## Best Practices

- ✅ Use environment variables or secure vaults for production
- ✅ Rotate API keys periodically
- ✅ Apply principle of least privilege to all credentials
- ✅ Enable API restrictions in Google Cloud Console
- ✅ Use different Firebase projects for dev/staging/prod
- ❌ Never commit `google-services.json` or API keys
- ❌ Never share OAuth tokens or JWT secrets
- ❌ Never hardcode credentials in source code
