<nav class="navbar navbar-expand-lg bg-body-tertiary fixed-top" data-bs-theme="dark">
  <!-- Navbar content -->
  <div class="container-fluid">
    <a class="navbar-brand" href="#"><?php echo NAVBAR_BRAND; ?></a>
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navbarNav">
      <ul class="navbar-nav">
        <li class="nav-item">
          <a class="nav-link <?php if (basename($_SERVER['PHP_SELF']) == 'index.php') {echo 'active';} ?>" aria-current="page" href="index.php">Home</a>
        </li>
        <li class="nav-item">
          <a class="nav-link <?php if (basename($_SERVER['PHP_SELF']) == 'ddc_dp.php') {echo 'active';} ?>" href="ddc_dp.php">Dynamic DB Credentials</a>
        </li>
<!--
        <li class="nav-item">
          <a class="nav-link <?php if (basename($_SERVER['PHP_SELF']) == 'adp_transform.php') {echo 'active';} ?>" href="adp_transform.php">Advanced Data Protection</a>
        </li>
-->
      </ul>
    </div>
  </div>
</nav>
