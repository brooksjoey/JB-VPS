#!/bin/bash
# === OKTA PHISHING EMAIL GENERATOR ===
# For authorized red team testing - wyndham Properties
# Generates realistic Okta security alert emails

set -euo pipefail
IFS=$'\n\t'

### === CONFIG ===
DOMAIN="your-domain.com"  # Replace with your phishing domain
CAMPAIGN_NAME="wyndham_okta_2024"
OUTPUT_DIR="./email_templates"
SENDER_EMAIL="security-alerts@okta.com"
SENDER_NAME="Okta Security Team"

### === COLORS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

### === FUNCTIONS ===
log() { echo -e "${BLUE}[EMAIL-GEN]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warning() { echo -e "${YELLOW}[!]${NC} $*"; }

setup_output() {
    mkdir -p "$OUTPUT_DIR"
    log "Created output directory: $OUTPUT_DIR"
}

generate_suspicious_login_email() {
    local template_file="$OUTPUT_DIR/suspicious_login.html"
    
    cat > "$template_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Okta Security Alert</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; }
        .header { background-color: #1662dd; padding: 20px; text-align: center; }
        .logo { color: white; font-size: 24px; font-weight: bold; }
        .content { padding: 30px; }
        .alert-box { background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px; padding: 15px; margin: 20px 0; }
        .alert-title { color: #856404; font-weight: bold; margin-bottom: 10px; }
        .details { background-color: #f8f9fa; padding: 15px; border-radius: 4px; margin: 20px 0; }
        .button { display: inline-block; background-color: #1662dd; color: white; padding: 12px 30px; text-decoration: none; border-radius: 4px; margin: 20px 0; }
        .footer { background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 12px; color: #6c757d; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Okta</div>
        </div>
        <div class="content">
            <h2>Security Alert: Suspicious Sign-In Attempt</h2>
            
            <div class="alert-box">
                <div class="alert-title">⚠️ Unusual Activity Detected</div>
                We detected a sign-in attempt from an unrecognized device or location.
            </div>
            
            <p>Hello,</p>
            <p>We noticed a sign-in attempt to your wyndham Properties account from a device or location we don't recognize.</p>
            
            <div class="details">
                <strong>Sign-in Details:</strong><br>
                📍 Location: Kyiv, Ukraine<br>
                🖥️ Device: Windows 10 - Chrome Browser<br>
                🕐 Time: Today at 2:43 PM EST<br>
                🌐 IP Address: 95.132.18.73
            </div>
            
            <p>If this was you, you can safely ignore this email. If you don't recognize this activity, please secure your account immediately.</p>
            
            <a href="https://{{DOMAIN}}/signin/verify?token={{LURE_TOKEN}}" class="button">Review Account Activity</a>
            
            <p style="margin-top: 30px; font-size: 14px; color: #6c757d;">
                For your security, this link will expire in 24 hours.
            </p>
        </div>
        <div class="footer">
            <p>This email was sent to you by Okta on behalf of wyndham Properties.<br>
            If you have questions, contact your system administrator.</p>
            <p>© 2024 Okta, Inc. • 301 Brannan Street, San Francisco, CA 94107</p>
        </div>
    </div>
</body>
</html>
EOF
    
    success "Generated: $template_file"
}

generate_password_reset_email() {
    local template_file="$OUTPUT_DIR/password_reset.html"
    
    cat > "$template_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Okta Password Reset</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; }
        .header { background-color: #1662dd; padding: 20px; text-align: center; }
        .logo { color: white; font-size: 24px; font-weight: bold; }
        .content { padding: 30px; }
        .button { display: inline-block; background-color: #1662dd; color: white; padding: 12px 30px; text-decoration: none; border-radius: 4px; margin: 20px 0; }
        .footer { background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 12px; color: #6c757d; }
        .security-note { background-color: #e7f3ff; border-left: 4px solid #1662dd; padding: 15px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Okta</div>
        </div>
        <div class="content">
            <h2>Password Reset Request</h2>
            
            <p>Hello,</p>
            <p>We received a request to reset the password for your wyndham Properties account. If you made this request, click the button below to create a new password.</p>
            
            <a href="https://{{DOMAIN}}/reset-password?token={{LURE_TOKEN}}" class="button">Reset Password</a>
            
            <div class="security-note">
                <strong>🔒 Security Reminder:</strong><br>
                For your protection, this password reset link will expire in 1 hour. If you didn't request this reset, please contact your system administrator immediately.
            </div>
            
            <p>If the button above doesn't work, copy and paste this link into your browser:</p>
            <p style="word-break: break-all; color: #1662dd;">https://{{DOMAIN}}/reset-password?token={{LURE_TOKEN}}</p>
        </div>
        <div class="footer">
            <p>This email was sent to you by Okta on behalf of wyndham Properties.<br>
            If you have questions, contact your system administrator.</p>
            <p>© 2024 Okta, Inc. • 301 Brannan Street, San Francisco, CA 94107</p>
        </div>
    </div>
</body>
</html>
EOF
    
    success "Generated: $template_file"
}

generate_mfa_setup_email() {
    local template_file="$OUTPUT_DIR/mfa_setup.html"
    
    cat > "$template_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Okta MFA Setup Required</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; }
        .header { background-color: #1662dd; padding: 20px; text-align: center; }
        .logo { color: white; font-size: 24px; font-weight: bold; }
        .content { padding: 30px; }
        .button { display: inline-block; background-color: #1662dd; color: white; padding: 12px 30px; text-decoration: none; border-radius: 4px; margin: 20px 0; }
        .footer { background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 12px; color: #6c757d; }
        .urgent-box { background-color: #fff2f2; border: 1px solid #ff6b6b; border-radius: 4px; padding: 15px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Okta</div>
        </div>
        <div class="content">
            <h2>🔐 Multi-Factor Authentication Setup Required</h2>
            
            <div class="urgent-box">
                <strong>Action Required by January 15, 2024</strong><br>
                Your account access will be suspended if MFA is not configured.
            </div>
            
            <p>Hello,</p>
            <p>As part of wyndham Properties' enhanced security initiative, all employees must configure Multi-Factor Authentication (MFA) on their accounts.</p>
            
            <p><strong>Why is this important?</strong></p>
            <ul>
                <li>Protects your account from unauthorized access</li>
                <li>Meets compliance requirements</li>
                <li>Prevents potential data breaches</li>
            </ul>
            
            <a href="https://{{DOMAIN}}/mfa/setup?token={{LURE_TOKEN}}" class="button">Setup MFA Now</a>
            
            <p style="margin-top: 30px; font-size: 14px; color: #6c757d;">
                Setup takes less than 5 minutes. You can use your mobile phone or authenticator app.
            </p>
        </div>
        <div class="footer">
            <p>This email was sent to you by Okta on behalf of wyndham Properties.<br>
            Questions? Contact IT Support at itsupport@wyndhamhotels.com</p>
            <p>© 2024 Okta, Inc. • 301 Brannan Street, San Francisco, CA 94107</p>
        </div>
    </div>
</body>
</html>
EOF
    
    success "Generated: $template_file"
}

generate_email_subjects() {
    local subjects_file="$OUTPUT_DIR/email_subjects.txt"
    
    cat > "$subjects_file" << 'EOF'
# Okta Email Subjects for wyndham Properties Campaign

## Suspicious Login Alerts
🚨 Unusual sign-in activity detected on your account
Security Alert: Unrecognized sign-in attempt
Action Required: Verify recent account activity
Your wyndham account was accessed from an unknown device
Okta Security: Please review your recent sign-ins

## Password Reset
Password reset requested for your wyndham account
Complete your password reset - Link expires soon
Secure your account: Password reset confirmation needed
Your wyndham Properties password reset request

## MFA Setup
🔐 MFA Setup Required - Action needed by [DATE]
Secure your wyndham account with two-factor authentication
Multi-factor authentication setup - Deadline approaching
IT Security: MFA configuration required for all employees
Your account needs additional security verification

## Account Locked/Suspended
⚠️ Your wyndham account has been temporarily suspended
Account security alert: Immediate action required
Your account access is at risk - Verify identity now
Security lockout: Confirm your identity to restore access
EOF
    
    success "Generated: $subjects_file"
}

create_campaign_script() {
    local script_file="$OUTPUT_DIR/send_campaign.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash
# Email Campaign Sender for wyndham Properties Red Team Exercise

DOMAIN="{{DOMAIN}}"
TARGET_LIST="targets.txt"
EMAIL_TEMPLATE="suspicious_login.html"

# Function to generate unique lure tokens
generate_token() {
    echo "$(date +%s)_$(openssl rand -hex 8)"
}

# Send emails (replace with your preferred method)
send_email() {
    local target="$1"
    local token="$(generate_token)"
    local personalized_email=$(sed "s/{{DOMAIN}}/$DOMAIN/g; s/{{LURE_TOKEN}}/$token/g" "$EMAIL_TEMPLATE")
    
    echo "Sending to: $target with token: $token"
    # Add your email sending logic here (SMTP, service, etc.)
    
    # Log the campaign
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),$target,$token" >> campaign_log.csv
}

# Main execution
if [ ! -f "$TARGET_LIST" ]; then
    echo "Error: $TARGET_LIST not found"
    exit 1
fi

echo "timestamp,target,token" > campaign_log.csv

while IFS= read -r target; do
    if [[ $target =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        send_email "$target"
        sleep 2  # Rate limiting
    fi
done < "$TARGET_LIST"

echo "Campaign complete. Check campaign_log.csv for results."
EOF
    
    chmod +x "$script_file"
    success "Generated: $script_file"
}

### === MAIN EXECUTION ===
main() {
    echo -e "${GREEN}"
    cat << "EOF"
    📧 OKTA EMAIL GENERATOR
    wyndham Properties Red Team Campaign
EOF
    echo -e "${NC}"
    
    log "Starting email template generation..."
    
    setup_output
    generate_suspicious_login_email
    generate_password_reset_email
    generate_mfa_setup_email
    generate_email_subjects
    create_campaign_script
    
    success "Email generation complete!"
    warning "Remember to:"
    echo "  1. Replace {{DOMAIN}} with your actual phishing domain"
    echo "  2. Create a targets.txt file with email addresses"
    echo "  3. Configure your email sending method in send_campaign.sh"
    echo "  4. Test emails before launching the campaign"
    
    log "Generated files in: $OUTPUT_DIR"
    ls -la "$OUTPUT_DIR"
}

main "$@"
