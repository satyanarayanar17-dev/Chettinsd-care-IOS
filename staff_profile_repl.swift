struct StaffProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var session: AuthSession?
    @State private var isLoading = true
    @State private var showingEdit = false
    
    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let session = session {
                    Section(header: Text("Staff Info")) {
                        HStack {
                            Text("Profile Picture")
                            Spacer()
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text(session.name?.prefix(1).uppercased() ?? "S")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                )
                        }
                        .padding(.vertical, 4)
                        
                        InfoRow(title: "Name", value: session.name ?? "Staff Member")
                        InfoRow(title: "Role", value: session.role)
                        InfoRow(title: "Status", value: "Active")
                    }
                }
                
                Section {
                    Button(action: { showingEdit = true }) {
                        Text("Edit Profile")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                Section {
                    Button(action: {
                        appState.logout()
                    }) {
                        Text("Sign Out")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingEdit) {
                if let session = session {
                    EditStaffProfileSheet(session: session)
                        .environmentObject(appState)
                }
            }
        }
        .task {
            self.session = await SessionManager.shared.getSession()
            self.isLoading = false
        }
    }
}

struct EditStaffProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    let session: AuthSession
    
    @State private var name: String
    @State private var email: String
    
    init(session: AuthSession) {
        self.session = session
        _name = State(initialValue: session.name ?? "")
        _email = State(initialValue: "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Info") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section {
                    Button("Manage Active Sessions (Revoke)") {
                        // In a real app this would present a list of sessions
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // TODO: Implement save
                        dismiss()
                    }
                }
            }
        }
    }
}
