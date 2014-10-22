//
//  Answer.swift
//  WeCenterMobile
//
//  Created by Darren Liu on 14/8/17.
//  Copyright (c) 2014年 ifLab. All rights reserved.
//

import Foundation
import CoreData

class Answer: NSManagedObject {

    @NSManaged var id: NSNumber
    @NSManaged var userID: NSNumber?
    @NSManaged var agreementCount: NSNumber?
    @NSManaged var body: String?
    @NSManaged var commentCount: NSNumber?
    @NSManaged var date: NSDate?
    @NSManaged var questionID: NSNumber?
    
    enum Evaluation: Int {
        case None = 0
        case Up = 1
        case Down = -1
    }
    var evaluation: Evaluation? = nil
    
    lazy var question: Question? = {
        var question: Question? = nil
        if self.questionID != nil {
            Question.fetchQuestionByID(self.questionID!,
                strategy: .CacheOnly,
                success: {
                    _question in
                    question = _question
                },
                failure: nil)
        }
        return question
    }()
    
    lazy var user: User? = {
        var user: User? = nil
        if self.userID != nil {
            User.fetchUserByID(self.userID!,
                strategy: .CacheOnly,
                success: {
                    _user in
                    user = _user
                },
                failure: nil)
        }
        return user
    }()
    
    private class func fetchDataForAnswerViewControllerUsingCacheByAnswerID(ID: NSNumber, success: (((Question, Answer, User)) -> Void)?, failure: ((NSError) -> Void)?) {
        fetchAnswerByID(ID,
            strategy: .CacheOnly,
            success: {
                answer in
                Question.fetchQuestionByID(answer.questionID!,
                    strategy: .CacheOnly,
                    success: {
                        question in
                        User.fetchUserByID(answer.userID!,
                            strategy: .CacheOnly,
                            success: {
                                user in
                                success?((question, answer, user))
                                return
                            },
                            failure: failure)
                    },
                    failure: failure)
            },
            failure: failure)
    }
    
    class func fetchAnswerByID(ID: NSNumber, strategy: Model.Strategy, success: ((Answer) -> Void)?, failure: ((NSError) -> Void)?) {
        switch strategy {
        case .CacheOnly:
            fetchAnswerUsingCacheByID(ID, success: success, failure: failure)
            break
        case .NetworkOnly:
            fetchAnswerUsingNetworkByID(ID, success: success, failure: failure)
            break
        case .CacheFirst:
            fetchAnswerUsingCacheByID(ID, success: success, failure: {
                error in
                self.fetchAnswerUsingNetworkByID(ID, success: success, failure: failure)
            })
            break
        case .NetworkFirst:
            fetchAnswerUsingNetworkByID(ID, success: success, failure: {
                error in
                self.fetchAnswerUsingCacheByID(ID, success: success, failure: failure)
            })
            break
        default:
            break
        }
    }
    
    private class func fetchAnswerUsingCacheByID(ID: NSNumber, success: ((Answer) -> Void)?, failure: ((NSError) -> Void)?) {
        Model.fetchManagedObjectByTemplateName("Answer_By_ID", ID: ID, success: success, failure: failure)
    }
    
    private class func fetchAnswerUsingNetworkByID(ID: NSNumber, success: ((Answer) -> Void)?, failure: ((NSError) -> Void)?) {
        let answer = Model.autoGenerateManagedObjectByEntityName("Answer", ID: ID) as Answer
        Model.GET("Answer Detail",
            parameters: [
                "id": ID
            ],
            success: {
                data in
                answer.id = data["answer_id"] as NSNumber
                answer.userID = data["uid"] as? NSNumber
                answer.questionID = data["question_id"] as? NSNumber
                answer.body = data["answer_content"] as? String
                answer.date = NSDate(timeIntervalSince1970: NSTimeInterval(data["add_time"] as NSNumber))
                answer.agreementCount = data["agree_count"] as? NSNumber
                answer.commentCount = data["comment_count"] as? NSNumber
                answer.evaluation = Evaluation.fromRaw(data["vote_value"] as NSNumber)
                let user = Model.autoGenerateManagedObjectByEntityName("User", ID: answer.userID!) as User
                user.name = data["user_name"] as? String
                let avatarURI = data["avatar_file"] as? String
                user.avatarURL = (avatarURI == nil) ? nil : User.avatarURLWithURI(avatarURI!)
                user.signature = data["signature"] as? String
                Question_Answer.updateRelationship(questionID: answer.questionID!, answerID: answer.id)
                User_Answer.updateRelationship(userID: user.id, answerID: answer.id)
                Question.fetchQuestionByID(answer.questionID!,
                    strategy: .CacheOnly,
                    success: {
                        question in
                        success?(answer)
                        return
                    },
                    failure: failure)
            },
            failure: failure)
    }

}
