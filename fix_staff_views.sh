#!/bin/bash
sed -i '' 's/\.font(.headline)/.font(Typography.titleMedium)/g' ChettinadCareStaff/Features/StaffViews.swift
sed -i '' 's/\.font(.subheadline)/.font(Typography.bodyLarge)/g' ChettinadCareStaff/Features/StaffViews.swift
sed -i '' 's/Color(.secondarySystemBackground)/Color.surfaceContainerLowest/g' ChettinadCareStaff/Features/StaffViews.swift
sed -i '' 's/spacing: 8/spacing: StitchSpacing.sm/g' ChettinadCareStaff/Features/StaffViews.swift
sed -i '' 's/spacing: 12/spacing: StitchSpacing.md/g' ChettinadCareStaff/Features/StaffViews.swift
sed -i '' 's/spacing: 16/spacing: StitchSpacing.lg/g' ChettinadCareStaff/Features/StaffViews.swift
sed -i '' 's/padding(8)/padding(StitchSpacing.sm)/g' ChettinadCareStaff/Features/StaffViews.swift
sed -i '' 's/padding(12)/padding(StitchSpacing.md)/g' ChettinadCareStaff/Features/StaffViews.swift
sed -i '' 's/padding(16)/padding(StitchSpacing.lg)/g' ChettinadCareStaff/Features/StaffViews.swift
sed -i '' 's/\.buttonStyle(.borderedProminent)/.buttonStyle(StitchPrimaryButtonStyle())/g' ChettinadCareStaff/Features/StaffViews.swift
