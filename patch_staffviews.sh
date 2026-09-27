#!/bin/bash
sed -i '' -e '/if let documents = bundle.documents, !documents.isEmpty {/,/}/d' ChettinadCareStaff/Features/StaffViews.swift
