<?php
  require_once('config.php');

  function get_encryption_key_version() {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_URL, VAULT_ADDR . '/v1/transit/keys/' . VAULT_ENCRYPTION_KEY);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_HTTPHEADER,
      Array(
        'X-Vault-Token: ' . TRANSIT_ENCRYPT_TOKEN
      )
    );
    $result = json_decode(curl_exec($ch), true);
    curl_close($ch);
    //echo '<pre>' . var_export($result, true) . '</pre>';
    return $result['data']['latest_version'];
  };

  function rek()
  {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_URL, VAULT_ADDR . '/v1/transit/keys/' . VAULT_ENCRYPTION_KEY . '/rotate');
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_HTTPHEADER,
      Array(
	      'X-Vault-Token: ' . TRANSIT_ENCRYPT_TOKEN
      )
    );
    curl_exec($ch);
    // if (!curl_errno($ch)) {
    //   $info = curl_getinfo($ch);
    //   echo '<pre>' . var_export($info, true) . '</pre>';
    // };
    curl_close($ch);
  };

  function encrypt($plaintext)
  {
    $post_string = json_encode(
      array(
        'plaintext' => base64_encode($plaintext)
      )
    );
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $post_string);
    curl_setopt($ch, CURLOPT_URL, VAULT_ADDR . '/v1/transit/encrypt/' . VAULT_ENCRYPTION_KEY);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_HTTPHEADER,
      Array(
	      'X-Vault-Token: ' . TRANSIT_ENCRYPT_TOKEN
      )
    );
    $result = json_decode(curl_exec($ch), true);
    curl_close($ch);
    #var_dump($result);
    return $result['data']['ciphertext'];
  };
  
  function decrypt($ciphertext)
  {
    $post_string = json_encode(
      array(
        'ciphertext' => $ciphertext
      )
    );
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $post_string);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_URL, VAULT_ADDR . '/v1/transit/decrypt/' . VAULT_ENCRYPTION_KEY);
    # /v1/mysql-demo/creds/demo-mysql-role-rw
    curl_setopt($ch, CURLOPT_HTTPHEADER,
      Array(
        'X-Vault-Token: ' . TRANSIT_DECRYPT_TOKEN
      )
    );
    $result = json_decode(curl_exec($ch), true);
    curl_close($ch);
    #var_dump($result);
    return base64_decode($result['data']['plaintext']);
    
  }
?>
