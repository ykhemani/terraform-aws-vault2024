<?php
  define ('SERVER', getenv('WEB_SERVER_URL'));
  define ('DDC_COOKIE', 'ddc');
  define ('EDP_COOKIE', 'edp');

  define ('VAULT_ADDR', getenv('VAULT_ADDR'));
  define ('VAULT_NAMESPACE', '/');
  define ('TRANSIT_ENCRYPT_TOKEN', getenv('TRANSIT_ENCRYPT_TOKEN'));
  define ('TRANSIT_DECRYPT_TOKEN', getenv('TRANSIT_DECRYPT_TOKEN'));
  define ('VAULT_ENCRYPTION_KEY', 'web-demo-key');
  define ('BRAND', '<i class="fa-brands fa-java"></i> HashiCafe');
  define ('NAVBAR_BRAND', BRAND . ' Demo Portal');
?>
