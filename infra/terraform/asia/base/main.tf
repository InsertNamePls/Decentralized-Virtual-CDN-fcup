####################################################
###################### VPC #########################
####################################################
module "NetworkAsia" {
  source = "../modules/gcp/network/vpc"

  project_name                    = var.project_id
  vpc_name                        = local.vpc_name
  auto_create_subnetworks         = false
  delete_default_routes_on_create = true
  routing_mode                    = "REGIONAL"
  route_name                      = "${local.vpc_name}-default-igw"
  next_hop_gateway                = "default-internet-gateway"
  route_priority                  = 1000
  dest_ip_range                   = "0.0.0.0/0"
}

####################################################
################## Private Subnet ##################
####################################################
module "PrivateAccessSubnetAsia" {
  source = "../modules/gcp/network/subnet"

  vpc_id         = module.NetworkAsia.vpc_id
  subnet_name    = local.private_subnet_name
  ip_cidr        = "10.10.0.0/24"
  subnet_purpose = "PRIVATE"
  region         = var.region

}

module "FirewallRulePrivateAsia" {
  source = "../modules/gcp/firewall_rules"

  rule_name          = "private-network-rules-asia"
  vpc_id             = module.NetworkAsia.vpc_id
  protocol           = "tcp"
  ports              = ["22", "443", "80", "3306", "11211"]
  source_ranges      = ["192.168.0.0/24", "10.10.0.0/24"]
  desitnation_ranges = ["0.0.0.0/0"]
  project_id         = var.project_id

  depends_on = [module.NetworkAsia]
}

module "PublicAccessSubnetAsia" {
  source = "../modules/gcp/network/subnet"

  vpc_id         = module.NetworkAsia.vpc_id
  subnet_name    = "pub-subnet-asia"
  ip_cidr        = "192.168.0.0/24"
  subnet_purpose = "PRIVATE"
  region         = var.region

  depends_on = [module.NetworkAsia]
}

module "FirewallRulePublicAsia" {
  source = "../modules/gcp/firewall_rules"

  rule_name          = "public-network-rules-asia"
  vpc_id             = module.NetworkAsia.vpc_id
  protocol           = "tcp"
  ports              = ["22", "443"]
  source_ranges      = concat(var.ip_isp_pub, ["10.10.0.0/24"])
  desitnation_ranges = ["0.0.0.0/0"]
  project_id         = var.project_id

  depends_on = [module.NetworkAsia]
}

module "ClientAsia" {
  source = "../modules/gcp/compute/private_vm"

  num_instances      = 2
  vm_name            = "client-asia"
  machine_type       = var.webapp_machine_type
  vpc_id             = module.NetworkAsia.vpc_id
  subnet             = local.private_subnet_name
  public_instance    = true
  image              = var.image
  provisioning_model = var.webapp_provisioning_model
  tags               = var.webapp_tags
  scopes             = var.scopes
  ssh_pub            = file(var.path_local_public_key)
  username           = var.username
  defaul_sa_name     = data.google_compute_default_service_account.default_sa.email
  available_zones    = ["asia-northeast1-a", "asia-northeast1-b", "asia-northeast1W-c"]
  packages           = "dnsutils memcached libmemcached-tools"
  depends_on = [module.NetworkAsia, module.PrivateAccessSubnetAsia]
}