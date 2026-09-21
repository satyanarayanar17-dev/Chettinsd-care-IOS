import SwiftUI
import ChettinadCore

struct TriageFormView: View {
    @StateObject var viewModel: TriageFormViewModel
    @Environment(\.dismiss) var dismiss
    let patientName: String
    
    var body: some View {
        Form {
            if let error = viewModel.errorMessage {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            Section(header: Text("Vitals")) {
                HStack {
                    Text("Temp (°C)")
                    Spacer()
                    TextField("e.g. 37.0", text: $viewModel.temperature)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Blood Pressure")
                    Spacer()
                    TextField("Sys", text: $viewModel.systolic)
                        .keyboardType(.numberPad)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                    Text("/")
                    TextField("Dia", text: $viewModel.diastolic)
                        .keyboardType(.numberPad)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Pulse (bpm)")
                    Spacer()
                    TextField("e.g. 80", text: $viewModel.pulse)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("SpO2 (%)")
                    Spacer()
                    TextField("e.g. 98", text: $viewModel.spo2)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Weight (kg)")
                    Spacer()
                    TextField("e.g. 70.5", text: $viewModel.weight)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section(header: Text("Complaint")) {
                TextEditor(text: $viewModel.complaint)
                    .frame(height: 80)
            }
        }
        .navigationTitle("Triage: \(patientName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Submit") {
                    Task {
                        if await viewModel.submitTriage() {
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel.isSubmitting || viewModel.isLoading)
            }
        }
        .task {
            // Only start triage once when the view appears.
            if viewModel.currentVersion == 0 { // Simplification, rely on actual version.
               // We should probably start triage if it's in WAITING state.
            }
            await viewModel.startTriage()
        }
        .overlay {
            if viewModel.isLoading || viewModel.isSubmitting {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
    }
}
