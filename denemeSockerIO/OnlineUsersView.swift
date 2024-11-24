// OnlineUsersView.swift
struct OnlineUsersView: View {
    let users: [String]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(users, id: \.self) { user in
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.green)
                        Text(user)
                    }
                }
            }
            .navigationTitle("Online Kullanıcılar")
            .navigationBarItems(trailing: Button("Kapat") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}