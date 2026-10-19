output "vpc_id" {
      description = "ID of the vpc"
    value = aws_vpc.main.id
}

output "vpc_cidr" {
      description = "CIDR block of the vpc"
    value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
      description = "List of public subnet IDs"
  value       = [for s in aws_subnet.public : s.id]
}

output "db_subnet_ids" {
  description = "List of db subnet IDs"
  value       = [for s in aws_subnet.db : s.id]
}