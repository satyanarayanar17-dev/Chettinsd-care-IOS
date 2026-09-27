sed -i '' '/func completeConsultation/i\
    func amendConsultation() async -> Bool {\
        guard let encounterId = encounterId else { return false }\
        isSubmitting = true\
        errorMessage = nil\
        do {\
            let cData = ConsultationData(\
                complaint: noteComplaint.isEmpty ? nil : noteComplaint,\
                history: noteHistory.isEmpty ? nil : noteHistory,\
                previous_history: nil,\
                examination: noteExamination.isEmpty ? nil : noteExamination,\
                assessment: noteAssessment.isEmpty ? nil : noteAssessment,\
                diagnosis_ids: Array(selectedDiagnoses),\
                treatment: nil,\
                advice: noteAdvice.isEmpty ? nil : noteAdvice,\
                medications: medications\
            )\
            let response: EncounterMutationResponse = try await apiClient.execute(\
                endpoint: AmendConsultEndpoint(encounterId: encounterId, v: currentVersion, data: cData, reason: amendReason)\
            )\
            if let newV = response.__v {\
                self.currentVersion = newV\
            }\
            consultationCompleted = true\
            isSubmitting = false\
            return true\
        } catch let error as APIError {\
            handleAPIError(error)\
        } catch {\
            self.errorMessage = error.localizedDescription\
        }\
        isSubmitting = false\
        return false\
    }\
' ChettinadCareStaff/Features/DoctorViewModels.swift
