#!/bin/bash
# Inject AppState in AdminDashboardView
sed -i '' 's/struct AdminDashboardView: View {/struct AdminDashboardView: View {\n    @EnvironmentObject var appState: AppState/g' ChettinadCareStaff/Features/AdminViews.swift

# Fix patient_id unwrapping
sed -i '' 's/appointment.patient_id.prefix(8)/(appointment.patient_id ?? "").prefix(8)/g' ChettinadCareStaff/Features/AdminViews.swift
