import SwiftUI

/// 账号列表：按类型分组展示，支持搜索、添加、点击进详情
struct AccountListView: View {
    @EnvironmentObject var vault: VaultStore
    @State private var showAdd = false
    @State private var searchText = ""

    private var groups: [(AccountType, [AccountItem])] {
        let filtered = searchText.isEmpty
            ? vault.items
            : vault.items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.account.localizedCaseInsensitiveContains(searchText)
            }
        return AccountType.allCases.compactMap { type in
            let arr = filtered.filter { $0.type == type }
            return arr.isEmpty ? nil : (type, arr)
        }
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
                    ForEach(groups, id: \.0) { type, items in
                        Section(header: Text(type.rawValue)) {
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

    var body: some View {
        Form {
            Section("类型") {
                Text(item.type.rawValue)
            }
            Section("标题") {
                Text(item.title.isEmpty ? "未命名" : item.title)
            }
            Section("账号") {
                HStack {
                    Text(item.account)
                    Spacer()
                    Button {
                        vault.copyText(item.account)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
            Section("密码") {
                HStack {
                    Text(revealPassword ? item.password : String(repeating: "•", count: item.password.count))
                        .animation(.easeInOut(duration: 0.2), value: revealPassword)
                    Spacer()
                    Button {
                        vault.copyText(item.password)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
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
        .sheet(isPresented: $showEdit) {
            AccountEditView(item: item, isNew: false)
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
