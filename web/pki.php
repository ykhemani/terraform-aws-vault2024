<?php
  $cert = openssl_x509_parse(file_get_contents('/run/secrets/web_pki_cert'));
  $valid_from = date('Y-m-d H:i:s', $cert['validFrom_time_t']);
  $valid_until = date('Y-m-d H:i:s', $cert['validTo_time_t']);
  echo '<pre>' . var_export($cert, true) . '</pre>';
?>