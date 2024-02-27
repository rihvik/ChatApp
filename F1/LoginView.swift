//
//  ContentView.swift
//  F1
//
//  Created by user2 on 30/01/24.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore



struct LoginView: View {
    
    let didCompleteLoginProcess: () -> ()
    
    @State private var isLoginMode = false
    @State private var email = ""
    @State private var password = ""
    @State var loginStatusMessage = ""
    @State private var shouldShowImagePicker = false
    @State var image: UIImage?
    
    
    
    var body: some View {
        NavigationView{
            ScrollView{
                VStack(spacing:16){
                    Picker(selection: $isLoginMode, label: Text("Picker here")){
                        Text("Login")
                            .tag(true)
                        Text("Create Account")
                            .tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if !isLoginMode {
                        
                        Button{
                            shouldShowImagePicker.toggle()
                        } label: {
                            
                            VStack{
                                if let image = self.image{
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width:128,height: 128)
                                        .cornerRadius(64)
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 64))
                                        .padding()
                                        .foregroundColor(Color(.label))
                                    
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 64).stroke(Color.black,lineWidth:3))
                       
                    }
                        
                    }
                    
                    Group{
                        TextField("Email",text:$email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
                        SecureField("Password",text:$password)
                            
                    }
                    .padding(12)
                    .background(.white)
                    
                    Button{
                        handleAction()
                        
                    } label: {
                        HStack{
                            Spacer()
                            Text(isLoginMode ? "Log In" : "Create Account")
                                .foregroundStyle(.white)
                                .padding(.vertical,10)
                            Spacer()
                        }
                        .background(.blue)
                    
                }
                    Text(self.loginStatusMessage)
                        .foregroundStyle(.red)
                
                }
                .padding()
                
            }
            .navigationTitle(isLoginMode ? "Log In" : "Create Account")
            .background(Color(.init(white: 0,alpha:0.05))
            .ignoresSafeArea())
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil) {
            ImagePicker(image: $image)
        }
    }
    private func handleAction(){
        if isLoginMode {
            //print("Should Login to Firebase with existing credentials")
            loginUser()
        }
        else {
            createNewAccount()
           // print("Register a account in firebase auth and store image in storage somehow")
        }
    }
    
    private func loginUser(){
        FirebaseManager.shared.auth.signIn(withEmail: email, password: password){
            result, err in
            if let err = err{
                print("Failed to login user: ",err)
                self.loginStatusMessage = "Failed to login user: \(err)"
                return
            }
            print("Successfully logged in as user: \(result?.user.uid ?? "")")
            self.loginStatusMessage = "Successfully logged in as user:\(result?.user.uid ?? "")"
            self.didCompleteLoginProcess()
        }
    }
    

    private func createNewAccount(){
        if self.image == nil {
            self.loginStatusMessage = "You must select an avatar image"
            return
        }
        FirebaseManager.shared.auth.createUser(withEmail: self.email, password: password){
            result, err in
            if let err = err{
                print("Failed to create user: ",err)
                self.loginStatusMessage = "Failed to create user: \(err)"
                return
            }
            print("Successfully created user: \(result?.user.uid ?? "")")
            self.loginStatusMessage = "Successfully created user:\(result?.user.uid ?? "")"
            self.persistImageToStorage()
        }
    }
    
    private func persistImageToStorage(){
 //       let filename = UUID().uuidString
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid
        else {
            return
        }
        let ref = FirebaseManager.shared.storage.reference(withPath: uid)
        guard let imageData = self.image?.jpegData(compressionQuality: 0.5) else {
            return
        }
        ref.putData(imageData, metadata: nil){
            metadata, err in
            if let err = err {
                self.loginStatusMessage = "Failed to push image to Storage: \(err)"
                return
            }
            ref.downloadURL{
                url,err in
                if let err = err {
                    self.loginStatusMessage = "Failed to retrieve downloadURL: \(err)"
                    return
                }
                self.loginStatusMessage = "Successfully stored image with url: \(url?.absoluteString ?? "")"
                print(url?.absoluteString)
                
                guard let url = url else {
                    return
                }
                self.storeUserInformation(imageProfileUrl:url)
            }
        }
    }
    private func storeUserInformation(imageProfileUrl: URL){
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            return
        }
        let userData = ["email":self.email,"uid":uid,"profileImageUrl": imageProfileUrl.absoluteString]
        FirebaseManager.shared.firestore.collection("users").document(uid).setData(userData){
            err in
            if let err = err {
                print(err)
                self.loginStatusMessage = "\(err)"
                return
            }
            print("Success")
            self.didCompleteLoginProcess()
        }
    }
}

#Preview {
    LoginView(didCompleteLoginProcess: {
        
    })
}
