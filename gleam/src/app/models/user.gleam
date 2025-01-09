pub type UserStatus {
  Active
  Inactive
}

pub type User {
  User(name: String, email: String, status: UserStatus)
}
