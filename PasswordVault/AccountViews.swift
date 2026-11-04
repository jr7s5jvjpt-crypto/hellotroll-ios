import SwiftUI

/// 账号列表：按类型分组展示，支持搜索、添加、点击进详情
struct AccountListView: View {
    @EnvironmentObject var vault: VaultStore
    @State private var showAdd = false
    @State private var searchText = ""

    private var groups: [(String, [AccountItem])] {
        let filtered = searchText.isEmpty
            ? vault.items
            : vault.items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.account.localizedCaseInsensitiveContains(searchText)
            }
        var dict: [String: [AccountItem]] = [:]
        for item in filtered {
            let name = typeDisplayName(for: item)
            dict[name, default: []].append(item)
        }
        return dict.map { ($0.key, $0.value) }
            .sorted { $0.0.localizedStandardCompare($1.0) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if groups.isEmpty {
                    Text("还没有账号，点右上角 + 添加")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                } else {
                    ForEach(groups, id: \.0) { name, items in
                        Section(header: Text(name)) {
                            ForEach(items) { item in
                                NavigationLink(destination: AccountDetailView(item: item)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title.isEmpty ? "未命名" : item.title)
                                        Text(item.account)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("账号")
            .animation(.easeInOut(duration: 0.25), value: vault.items)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AccountEditView(item: AccountItem(), isNew: true)
            }
        }
    }
}

/// 账号详情：查看、复制账号/密码、编辑、删除
struct AccountDetailView: View {
    @EnvironmentObject var vault: VaultStore
    @State var item: AccountItem
    @State private var showEdit = false
    @State private var revealPassword = false
    @State private var copiedField: String?

    var body: some View {
        Form {
            Section("类型") {
                Text(typeDisplayName(for: item))
            }
            Section("标题") {
                Text(item.title.isEmpty ? "未命名" : item.title)
            }
            Section("账号") {
                HStack {
                    Text(item.account)
                    Spacer()
                    copyButton(field: "账号", value: item.account)
                }
            }
            Section("密码") {
                HStack {
                    Text(revealPassword ? item.password : String(repeating: "•", count: item.password.count))
                        .animation(.easeInOut(duration: 0.2), value: revealPassword)
                    Spacer()
                    copyButton(field: "密码", value: item.password)
                        .padding(.trailing, 22)   // 与“显示密码”按钮拉开距离，避免误触
                    Button {
                        revealPassword.toggle()
                    } label: {
                        Image(systemName: revealPassword ? "eye.slash" : "eye")
                    }
                }
            }
            if !item.note.isEmpty {
                Section("备注") {
                    Text(item.note)
                }
            }
            Section {
                Button("删除", role: .destructive) {
                    vault.delete(item)
                }
            }
        }
        .navigationTitle("详情")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("编辑") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: refreshItem) {
            AccountEditView(item: item, isNew: false)
        }
    }

    /// 复制按钮：点击后图标短暂变绿打勾并显示“已复制”，1.5 秒后恢复
    private func copyButton(field: String, value: String) -> some View {
        Button {
            vault.copyText(value)
            withAnimation(.easeInOut(duration: 0.2)) {
                copiedField = field
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedField == field {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        copiedField = nil
                    }
                }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: copiedField == field ? "checkmark" : "doc.on.doc")
                    .foregroundColor(copiedField == field ? .green : .blue)
                if copiedField == field {
                    Text("已复制")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: copiedField)
        }
    }

    /// 编辑保存后从数据源刷新当前条目，详情页立即显示最新内容
    private func refreshItem() {
        if let updated = vault.items.first(where: { $0.id == item.id }) {
            item = updated
        }
    }
}

/// 添加 / 编辑账号表单
struct AccountEditView: View {
    @EnvironmentObject var vault: VaultStore
    @Environment(\.dismiss) var dismiss
    @State var item: AccountItem
    var isNew: Bool

    var body: some View {
        NavigationStack {
            Form {
                Picker("类型", selection: $item.type) {
                    ForEach(AccountType.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                if item.type == .custom {
                    TextField("自定义类型名称", text: $item.customType)
                }
                TextField("标题（如：微信）", text: $item.title)
                TextField("账号 / 用户名", text: $item.account)
                SecureField("密码", text: $item.password)
                TextField("备注（可选）", text: $item.note)
            }
            .navigationTitle(isNew ? "添加账号" : "编辑账号")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if isNew {
                            vault.add(item)
                        } else {
                            vault.update(item)
                        }
                        dismiss()
                    }
                    .disabled(item.title.isEmpty && item.account.isEmpty)
                }
            }
        }
    }
}
