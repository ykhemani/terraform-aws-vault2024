<?php
  require_once('config.php');
  require_once('protect.php');
  include('_header.php');
  include('_nav.php');
?>
<div id="space">&nbsp;</div>

<h1><?php echo BRAND; ?> Vault Demo Application</h1>
<div id="space">&nbsp;</div>

<h2><i class="fa-solid fa-lock"></i> Dynamic PKI Certificate Information</h2>

<div id="form" class="bg-primary-subtle text-dark rounded-3 p-3">
<?php
  $url = "https://127.0.0.1";
  $orignal_parse = parse_url($url, PHP_URL_HOST);
  $get = stream_context_create(
    array(
    "ssl" => array(
      "capture_peer_cert" => true,
      "verify_peer"       => false,
      "verify_peer_name"  => false
      )
    )
  );
  $read = stream_socket_client("ssl://".$orignal_parse.":443", $errno, $errstr, 30, STREAM_CLIENT_CONNECT,  $get);
  $cert = stream_context_get_params($read);
  $certinfo = openssl_x509_parse($cert['options']['ssl']['peer_certificate']);
  $common_name = $certinfo['subject']['CN'];
  $valid_from = date_create_from_format('ymdHise', $certinfo['validFrom'])->format('Y-m-d H:i:s P');
  $valid_until = date_create_from_format('ymdHise', $certinfo['validTo'])->format('Y-m-d H:i:s P');
  $serial_number = $certinfo['serialNumberHex'];
  $issuer_url = $certinfo['extensions']['authorityInfoAccess'];
  preg_match('/http.+/',$issuer_url, $issuer_url);
  $issuer_url = $issuer_url[0] . '_chain';

  //echo '<pre>';
  //print_r($certinfo);
  //echo '</pre>';
?>

              <form>
                <div class="form-group row fs-5 font-monospace mb-3">
                    <label for="common_name" class="col-sm-4 col-form-label">Common name:</label>
                    <div class="col-sm-4">
                        <input type="text" class="form-control" id="common_name" name="common_name" value="<?php echo $common_name; ?>" disabled>
                    </div>
                </div>
                
                <div class="form-group row fs-5 font-monospace mb-3">
                    <label for="valid_from" class="col-sm-4 col-form-label">Valid from:</label>
                    <div class="col-sm-4">
                        <input type="text" class="form-control" id="valid_from" name="valid_from" value="<?php echo $valid_from; ?>" disabled>
                    </div>
                </div>

                <div class="form-group row fs-5 font-monospace mb-3">
                    <label for="valid_until" class="col-sm-4 col-form-label">Valid until:</label>
                    <div class="col-sm-4">
                        <input type="text" class="form-control" id="valid_until" name="valid_until" value="<?php echo $valid_until; ?>" disabled>
                    </div>
                </div>

                <div class="form-group row fs-5 font-monospace mb-3">
                    <label for="ca_cert_download" class="col-sm-4 col-form-label">Download CA Certificate</label>
                    <div class="col-sm-4">
                      <a class="btn btn-primary" href="<?php echo $issuer_url; ?>">CA Certificate</a>
                    </div>
                </div>

              </form>
              <div class="font-monospace mb-3 form-group">
                The <?php echo BRAND; ?> uses short-lived PKI certificates issued by Vault.
              </div>

              </div>

<?php
  include('_footer.php');
?>
