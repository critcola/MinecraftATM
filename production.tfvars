organization = cc
application = mc
environment = prod

region = us-east-1
az = us-east-1b
mgt_sg = sg-0bbe76bb749d955c3
key_name = cc

instance_specs = {
  instance_type = "r5.xlarge"
  spot_bid = 0.26 # TODO: FIX?
  key_name = cc
  base_volume_size = 8
  base_volume_type = gp3
  game_volume = "vol-0737fc1633a61d082"
}

zone_id = c9005a9b4113d5ed1592370b9c078b47