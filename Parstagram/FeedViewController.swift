//
//  FeedViewController.swift
//  Parstagram
//
//  Created by Henry Liu on 3/25/22.
//

import UIKit
import Parse
import AlamofireImage
import MessageInputBar

class FeedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MessageInputBarDelegate {
    
    // Outlets:
    @IBOutlet weak var tableView: UITableView!
    
    // variables:
    var refreshControl: UIRefreshControl!
    
    let commentBar = MessageInputBar()
    var showsCommentBar = false
    
    var posts = [PFObject]()
    var numberOfFeeds : Int!
    
    var selectedPost : PFObject!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self
        
        commentBar.inputTextView.placeholder = "Add a comment..."
        commentBar.sendButton.title = "Post"
        commentBar.delegate = self
        
        // for the refreshor:
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(onRefresh), for: .valueChanged)
        tableView.insertSubview(refreshControl, at: 0)
        tableView.refreshControl = refreshControl
        
        tableView.keyboardDismissMode = .interactive
        
        let center = NotificationCenter.default
        
        // when the event happen (told by the observer), call keyboardWillBeHidden()
        center.addObserver(self, selector: #selector(keyboardWillBeHidden(note:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // will be called when the keyboard is hiding
    @objc func keyboardWillBeHidden(note: Notification) {
        // clear the textfield
        commentBar.inputTextView.text = nil
        
        showsCommentBar = false
        becomeFirstResponder()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // get the query
        let query = PFQuery(className:"Posts")
        query.includeKeys(["author", "comments", "comments.author"])
        self.numberOfFeeds = 20
        query.limit = numberOfFeeds
        
        // upon getting the movie back, put them into the array
        // And then reload the tableview cell data
        query.findObjectsInBackground { (posts, error) in
            if posts != nil {
                self.posts = posts!
                self.tableView.reloadData()
            }
        }
    }
    
    func messageInputBar(_ inputBar: MessageInputBar, didPressSendButtonWith text: String) {
        // crete the comment
        let comment = PFObject(className: "Comments")
        comment["text"] = text
        comment["post"] = selectedPost
        comment["author"] = PFUser.current()!

        // add the comments array to the post
        selectedPost.add(comment, forKey: "comments")

        selectedPost.saveInBackground { (success, Error) in
            if success {
                print("Comment saved")
            } else {
                print("Error saving comment")
            }
        }
        
        // refresh the tableView
        tableView.reloadData()
        
        // clear and dismiss the input bar
        commentBar.inputTextView.text = nil
        showsCommentBar = false
        becomeFirstResponder()
        commentBar.inputTextView.resignFirstResponder()
    }
    
    override var inputAccessoryView: UIView? {
        return commentBar
    }
    
    override var canBecomeFirstResponder: Bool {
        return showsCommentBar
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let post = posts[section]
        let comments = (post["comments"] as? [PFObject]) ?? []
        
        return comments.count + 2
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return posts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // grab the post and its comment
        let post = posts[indexPath.section]
        let comments = (post["comments"] as? [PFObject]) ?? []
        
        // if the indexPath.row is 0, then it is a post
        if (indexPath.row == 0) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PostCell") as! PostCell
            
            let user = post["author"] as! PFUser
            cell.usernameLabel.text = user.username
            cell.captionLabel.text = post["caption"] as! String
            
            let imageFile = post["image"] as! PFFileObject
            let urlString = imageFile.url!
            let url = URL(string: urlString)!
            
            cell.photoView.af.setImage(withURL: url)
            
            return cell
        } else if (indexPath.row <= comments.count) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell") as! CommentCell
            
            let comment = comments[indexPath.row - 1]
            cell.commentLabel.text = comment["text"] as? String
            
            let user = comment["author"] as! PFUser
            cell.nameLabel.text = user.username
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AddCommentCell")!
            
            return cell
        }
    }
    
    // for the refresher
    @objc func onRefresh() {
        run(after: 1) {
            self.refreshControl.endRefreshing()
        }
        
        numberOfFeeds += 20
        
        // get the query
        let query = PFQuery(className:"Posts")
        query.includeKey("author")
        query.limit = numberOfFeeds
        
        // upon getting the movie back, put them into the array
        // And then reload the tableview cell data
        query.findObjectsInBackground { (posts, error) in
            if posts != nil {
                self.posts = posts!
                self.tableView.reloadData()
            }
        }
    }

    // implement the delay method
    func run(after wait: TimeInterval, closure: @escaping () -> Void) {
        let queue = DispatchQueue.main
        queue.asyncAfter(deadline: DispatchTime.now() + wait, execute: closure)
    }
    
    
    @IBAction func onLogoutButton(_ sender: Any) {
        
        PFUser.logOut()
        
        // grab the storyboard and initiate the viewController
        let main = UIStoryboard(name: "Main", bundle: nil)
        let loginViewController = main.instantiateViewController(withIdentifier: "LoginViewController")
        
        // grab the window variable from sceneDelegate
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let delegate = windowScene.delegate as? SceneDelegate else { return }
        
        delegate.window?.rootViewController = loginViewController
        
    }
    
    // for comments:
    //  This function will be called everytime the table cell is being tapped
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // get the post user selected
        let post = posts[indexPath.section]
        
        // create comment object (PFObject)
        let comments = (post["comments"] as? [PFObject]) ?? []
        
        
        if (indexPath.row == comments.count + 1) {
            showsCommentBar = true
            becomeFirstResponder() // because we have the overriden canBecomeFirstResponder(), showsCommentBar will get re-evaluated
            
            commentBar.inputTextView.becomeFirstResponder()
            
            selectedPost = post
        }
    }
}
