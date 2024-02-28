//
//  MainMessagesView.swift
//  F1
//
//  Created by user2 on 04/02/24.
//

import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore

struct RecentMessage: Identifiable {
    var id: String {
        documentId
    }
    let documentId: String
    let text, email: String
    let fromId,toId: String
    let profileImageUrl: String
    let timestamp: Timestamp
    init(documentId: String, data: [String:Any]){
        self.documentId = documentId
        self.text = data["text"] as? String ?? ""
        self.fromId = data["fromId"] as? String ?? ""
        self.toId = data["toId"] as? String ?? ""
        self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
        self.email = data["email"] as? String ?? ""
        self.timestamp = data["timestamp"] as? Timestamp ?? Timestamp(date: Date())
    }
}

class  MainMessagesViewModel: ObservableObject{
    
    @Published var errorMessage = ""
    @Published var chatUser : ChatUser?
    @Published var isUserCurrentlyLoggedOut = false
    
    
    init(){
        DispatchQueue.main.async{
            self.isUserCurrentlyLoggedOut = FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        fetchCurrentUser()
        fetchRecentMessages()
    }
    @Published var recentMessages = [RecentMessage]()
    private func fetchRecentMessages(){
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            return
        }
        FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener{ querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for recent messages:\(error)"
                    print(error)
                    return
                }
                
                querySnapshot?.documentChanges.forEach({change in
                    
                        let docId = change.document.documentID
                        if let index =
                            self.recentMessages.firstIndex(where: { rm in return rm.documentId == docId}){
                            self.recentMessages.remove(at:index)
                        }
                    self.recentMessages.insert(.init(documentId: docId,data: change.document.data()),at:0)
                    
                })
            }
    }
    func fetchCurrentUser(){
       
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return }
        
        FirebaseManager.shared.firestore.collection("users")
            .document(uid).getDocument{ snapshot, error in
                if let error = error{
                    self.errorMessage = "Failed to fetch current user:\(error)"
                    print("Failed to fetch current user:",error)
                    return
                }
 //               self.errorMessage = "123"
                guard let data = snapshot?.data() else {
                    self.errorMessage = "No Data Found"
                    return }
                //print(data)
                
 //               self.errorMessage = "Data: \(data.description)"
                self.chatUser = .init(data: data)
                
  //              self.errorMessage = chatUser.profileImageUrl
            }
    }
    
    func handleSignOut(){
        isUserCurrentlyLoggedOut.toggle()
        try? FirebaseManager.shared.auth.signOut()
    }
}

struct MainMessagesView: View {
    
    @State var shouldShowLogOutOptions = false
    @State var shouldNavigateToChatLogView = false
    @ObservedObject private var vm = MainMessagesViewModel()
    
    var body: some View {
        NavigationView {
            
            VStack {
                customNavBar
                messagesView
                
                NavigationLink("", isActive: $shouldNavigateToChatLogView){
                    ChatLogView(chatUser: self.chatUser)
                }
            }
            .overlay(
                newMessageButton, alignment: .bottom)
            .navigationBarHidden(true)
        }
    }
    
    private var customNavBar: some View {
        HStack(spacing: 16) {
            WebImage(url: URL(string: vm.chatUser?.profileImageUrl ?? ""))
                .resizable()
                .frame(width:50,height: 50)
                .clipped()
                .cornerRadius(50)
                .overlay(RoundedRectangle(cornerRadius: 44)
                            .stroke(Color(.label), lineWidth: 1)
                )
                .shadow(radius: 5)
            
   //         Image(systemName: "person.fill")
     //           .font(.system(size: 34, weight: .heavy))
            
            VStack(alignment: .leading, spacing: 4) {
                let email =
                vm.chatUser?.email.replacingOccurrences(of: "@gmail.com", with: "") ?? ""
                Text(email)
                    .font(.system(size: 24, weight: .bold))
                
                HStack {
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: 14, height: 14)
                    Text("online")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.lightGray))
                }
                
            }
            
            Spacer()
            Button {
                shouldShowLogOutOptions.toggle()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(.label))
            }
        }
        .padding()
        .actionSheet(isPresented: $shouldShowLogOutOptions) {
            .init(title: Text("Settings"), message: Text("What do you want to do?"), buttons: [
                .destructive(Text("Sign Out"), action: {
                    print("handle sign out")
                    vm.handleSignOut()
                }),
                    .cancel()
            ])
        }
        .fullScreenCover(isPresented: $vm.isUserCurrentlyLoggedOut, onDismiss: nil){
            LoginView(didCompleteLoginProcess: {
                self.vm.isUserCurrentlyLoggedOut = false
                self.vm.fetchCurrentUser()
            })
        }
    }
    
    
    
    private var messagesView: some View {
        ScrollView {
            ForEach(vm.recentMessages) { recentMessage in
                VStack {
                    NavigationLink(destination: ChatLogView(chatUser: self.chatUser)) {
                        HStack(spacing: 16) {
                            WebImage(url: URL(string: recentMessage.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width:64,height:64)
                                .clipped()
                                .cornerRadius(64)
                                .overlay(RoundedRectangle(cornerRadius: 64).stroke(Color.black,lineWidth: 2))
                                .shadow(radius: 5)
                            
                            
                            VStack(alignment: .leading,spacing:8) {
                                Text(recentMessage.email)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(.label))
                                Text(recentMessage.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(.darkGray))
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            
                            Text(timeAgoSinceDate(recentMessage.timestamp, currentDate: Date()))
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                }.padding(.horizontal)
                
            }.padding(.bottom, 50)
        }
    }
    
    @State var shouldShoeNewMessageScreen = false
    private var newMessageButton: some View {
        Button {
            shouldShoeNewMessageScreen.toggle()
        } label: {
            HStack {
                Spacer()
                Text("+ New Message")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical)
                .background(Color.blue)
                .cornerRadius(32)
                .padding(.horizontal)
                .shadow(radius: 15)
        }
        .fullScreenCover(isPresented: $shouldShoeNewMessageScreen) {
            CreateNewMessageView(didSelectNewUser : {
                user in print(user.email)
                self.shouldNavigateToChatLogView.toggle()
                self.chatUser = user
            })
        }
    }
    @State var chatUser : ChatUser?
    private func timeAgoSinceDate(_ date: Timestamp, currentDate: Date, numericDates: Bool = false) -> String {
            let calendar = Calendar.current
            let now = currentDate
        let earliest = (date.seconds < Int64(now.timeIntervalSince1970)) ? date.dateValue() : now
        let latest = (date.seconds > Int64(now.timeIntervalSince1970)) ? date.dateValue() : now
            
            let components: Set<Calendar.Component> = [.second, .minute, .hour, .day, .weekOfYear, .month, .year]
            let difference = calendar.dateComponents(components, from: earliest, to: latest)
            
            if difference.year! >= 2 {
                return "\(difference.year!) yrs ago"
            } else if difference.year! >= 1 {
                if numericDates {
                    return "1 yr ago"
                } else {
                    return "Last year"
                }
            } else if difference.month! >= 2 {
                return "\(difference.month!) months ago"
            } else if difference.month! >= 1 {
                if numericDates {
                    return "1 mth ago"
                } else {
                    return "Last month"
                }
            } else if difference.weekOfYear! >= 2 {
                return "\(difference.weekOfYear!) weeks ago"
            } else if difference.weekOfYear! >= 1 {
                if numericDates {
                    return "1 week ago"
                } else {
                    return "Last week"
                }
            } else if difference.day! >= 2 {
                return "\(difference.day!) days ago"
            } else if difference.day! >= 1 {
                if numericDates {
                    return "1 day ago"
                } else {
                    return "Yesterday"
                }
            } else if difference.hour! >= 2 {
                return "\(difference.hour!) hours ago"
            } else if difference.hour! >= 1 {
                if numericDates {
                    return "1 hr ago"
                } else {
                    return "An hr ago"
                }
            } else if difference.minute! >= 2 {
                return "\(difference.minute!) min ago"
            } else if difference.minute! >= 1 {
                if numericDates {
                    return "1 min ago"
                } else {
                    return "A min ago"
                }
            } else if difference.second! >= 3 {
                return "\(difference.second!) sec ago"
            } else {
                return "Just now"
            }
        }
}

#Preview {
    MainMessagesView()
}

