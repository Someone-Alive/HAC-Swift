// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import SwiftUI
import SwiftSoup

open class HACSession : ObservableObject {
    
    @Published public private(set) var markingPeriods: [MarkingPeriod] = []
    @Published public private(set) var status: HACSessionUserStatus = .loggedOut
    
    //MARK: Status
    ///The status indicator for login()
    
    public enum HACSessionUserStatus: Sendable {
        case loggedIn, loggedOut
    }
    
    public enum HACSessionStatus: Sendable {
        case failed, passed
    }
    
    //MARK: User Related Struct
    public struct HACStudent: Identifiable, Hashable, Codable, Sendable {
        public var id = UUID()
        public var studentID: String
        public var studentName: String
        public var studentBirthdate: String
        public var studentCounselor: String
        public var studentBuilding: String
        public var studentGrade: String
        public var studentLanguage: String
        
        public init(id: UUID = UUID(), studentID: String, studentName: String, studentBirthdate: String, studentCounselor: String, studentBuilding: String, studentGrade: String, studentLanguage: String) {
            self.id = id
            self.studentID = studentID
            self.studentName = studentName
            self.studentBirthdate = studentBirthdate
            self.studentCounselor = studentCounselor
            self.studentBuilding = studentBuilding
            self.studentGrade = studentGrade
            self.studentLanguage = studentLanguage
        }
    }
    
    //MARK: Marking Period related structs
    public struct Assignment: Identifiable, Hashable, Codable, Sendable {
        public var id = UUID()
        public var dateDue: String
        public var dateAssigned: String
        public var name: String
        public var category: String
        public var score: String
        public var totalPoints: String
        public var weight: String
        public var weightedScore: String
        public var weightedTotalPoints: String
        public var strikeThrough: Bool = false
        public var custom: Bool = false
        
        public init(id: UUID = UUID(), dateDue: String, dateAssigned: String, name: String, category: String, score: String, totalPoints: String, weight: String, weightedScore: String, weightedTotalPoints: String, strikeThrough: Bool, custom: Bool) {
            self.id = id
            self.dateDue = dateDue
            self.dateAssigned = dateAssigned
            self.name = name
            self.category = category
            self.score = score
            self.totalPoints = totalPoints
            self.weight = weight
            self.weightedScore = weightedScore
            self.weightedTotalPoints = weightedTotalPoints
            self.strikeThrough = strikeThrough
            self.custom = custom
        }
    }

    public struct Class: Identifiable, Hashable, Codable, Sendable {
        public var id = UUID()
        public var name: String
        public var score: String
        public var weight: Double
        public var credits: Double
        public var assignments: [Assignment]
        public var categories: [String : [String : String]] // [Category : Weight]
        
        public init(id: UUID = UUID(), name: String, score: String, weight: Double, credits: Double, assignments: [Assignment], categories: [String : [String : String]]) {
            self.id = id
            self.name = name
            self.score = score
            self.weight = weight
            self.credits = credits
            self.assignments = assignments
            self.categories = categories
        }
    }

    public struct MarkingPeriod: Identifiable, Hashable, Codable, Sendable {
        public var id = UUID()
        public var period: String
        public var classes: [Class]
        
        public init(id: UUID = UUID(), period: String, classes: [Class]) {
            self.id = id
            self.period = period
            self.classes = classes
        }
    }
    
    //MARK: Variables
    private let username: String
    private let password: String
    private let url: String
    private let useAnimation: Bool
    
    private let districtName: String
    private let hacName: String
    
    private let timeoutInterval: Double
    
    //API Version
    private let version: String = "1.0.0"
    
    //MARK: Initializers
    ///Username: takes in a string representation of the username
    ///Password: takes in a string represenation of the password
    ///URL: needs to be a host url: (subdomain + domain + top level domain) for example insteasd of https://www.google.com/hac-swift/api.... etc just put (www.google.com)
    ///useAnimation: set actions will be used inside withAnimation to provide better visuals
    ///timeoutInterval: defines when networks requests will timeout
    
    public init(username: String, password: String, url: String, useAnimation: Bool, districtName: String, hacName: String, timeoutInterval: Double) {
        self.username = username
        self.password = password
        self.url = url
        self.useAnimation = useAnimation
        self.districtName = districtName
        self.hacName = hacName
        self.timeoutInterval = timeoutInterval
    }
    
    
    //MARK: Login
    private var localToken: String = ""
    private var database: String = ""
    private var sessionAvailability: HACSessionStatus = .failed
    
    private func requestSession() async -> HACSessionStatus {
        var request = URLRequest(url: URL(string: "https://\(url)/HomeAccess/Account/LogOn")!)
        request.httpMethod = "POST"
        
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.125 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("\(url)", forHTTPHeaderField: "Host")
        request.setValue("\(url)", forHTTPHeaderField: "Origin")
        request.setValue("https://\(url)/HomeAccess/Account/LogOn", forHTTPHeaderField: "Referer")
        request.setValue(localToken, forHTTPHeaderField: "__RequestVerificationToken")
        
        let params: [String: Any] = [
            "__RequestVerificationToken": localToken,
            "Database": "\(database)",
            "LogOnDetails.UserName": username,
            "LogOnDetails.Password" : password
        ]
        request.httpBody = params.percentEncoded()
        request.timeoutInterval = timeoutInterval
        
        return await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) {(data, response, error) in
                if error != nil {
                    print("requestSession had an error")
                    continuation.resume(returning: .failed)
                    return
                }
                
                guard let data = data else {
                    print("No data was returned from requestSession()")
                    continuation.resume(returning: .failed)
                    return
                }
                
                do {
                    let doc: Document = try SwiftSoup.parse(String(data: data, encoding: .utf8)!)
                    
                    if try doc.getElementsByTag("form").first()?.attr("action") == "/HomeAccess/Account/LogOn" {
                        continuation.resume(returning: .failed)
                        return
                    }
                    else {
                        continuation.resume(returning: .passed)
                        return
                    }
                } catch {
                    print("unable to request session: \(error)")
                }
                
                continuation.resume(returning: .passed)
                return
            }
            
            task.resume()
        }
    }
    
    //MARK: Public Login function
    ///This function handles both the session token param that hac requires and the login itself
    ///Your should call this function first before anything.
    ///
    ///Returns (HACSessionStatus)
    ///(HACSessionStatus) If successfully logged in, returns passed if not, returns failed
    public func login() async -> HACSessionStatus {
        let hacName = self.hacName
        
        var request = URLRequest(url: URL(string: "https://\(self.url)/HomeAccess/Account/LogOn")!)
        request.timeoutInterval = self.timeoutInterval
        
        //Status, localToken, database
        let result: (HACSessionStatus, String, String) = await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) {(data, response, error) in
                if error != nil {
                    continuation.resume(returning: (.failed, "", ""))
                    return
                }
                
                guard let data = data else {
                    continuation.resume(returning: (.failed, "", ""))
                    return
                }
                do {
                    let doc: Document = try SwiftSoup.parse(String(data: data, encoding: .utf8)!)
                    
                    let localToken = try doc.getElementsByTag("input").attr("name", "__RequestVerificationToken").attr("value")
                    
                    print("Got token with value: \(localToken)")
                    
                    var database = try doc.getElementById("Database")?.attr("value") ?? "err"
                    
                    print("DATABASE: \(database)")
                    
                    if database == "err" || database == "" || database == " " {
                        let cod = try doc.getElementById("Database")?.tagName()
                        if cod == "select" {
                            let options = try doc.getElementById("Database")?.children().array() ?? []
                            for option in options {
                                print("OPTION: \(option)")
                                if try option.text() == hacName {
                                    database = try option.attr("value")
                                    break
                                }
                            }
                        }
                        else {
                            continuation.resume(returning: (.failed, "", ""))
                            return
                        }
                    }
                    continuation.resume(returning: (.passed, localToken, database))
                } catch Exception.Error(_, let message) {
                    print("getSessionToken had an error because: \(message)")
                    continuation.resume(returning: (.failed, "", ""))
                    return
                } catch {
                    print("getSessionToken had an unknown error")
                    continuation.resume(returning: (.failed, "", ""))
                    return
                }
            }
            task.resume()
        }
        
        localToken = result.1
        database = result.2
        
        if result.0 == .passed {
            self.sessionAvailability = await requestSession()
            if self.sessionAvailability == .passed {
                self.status = .loggedIn
            }
            return self.sessionAvailability
        }
        else {
            return result.0
        }
    }
    
    
    //MARK: USER INFO
    ///Gets the information about a user provided through HAC
    public func getUserInfo() async -> HACStudent? {
        if self.sessionAvailability == .passed {
            let result: HACStudent = await withCheckedContinuation { continuation in
                let url = URL(string: "https://\(self.url)/HomeAccess/Content/Student/Registration.aspx")!
                var request = URLRequest(url: url)

                request.timeoutInterval = timeoutInterval
                
                let task = URLSession.shared.dataTask(with: request) {(data, res, err) in
                    guard let data = data else {
                        print("no data was returned: getUserInfo()")
                        continuation.resume(returning: HACStudent(studentID: "", studentName: "", studentBirthdate: "", studentCounselor: "", studentBuilding: "", studentGrade: "", studentLanguage: ""))
                        return
                    }
                    
                    Task {
                        do {
                            //Name formatter
                            func formatName(fullName: String) async -> String {
                                let formatter = PersonNameComponentsFormatter()
                                guard let components = formatter.personNameComponents(from: fullName) else {
                                    return fullName // Return original if formatting fails
                                }

                                return formatter.string(from: components)
                            }
                            
                            let doc: Document = try SwiftSoup.parse(String(data: data, encoding: .utf8)!)
                            
                            let sID = try doc.getElementById("plnMain_lblRegStudentID")?.text() ?? "N/A"
                            
                            var sName = try doc.getElementById("plnMain_lblRegStudentName")?.text() ?? "N/A"
                            sName = await formatName(fullName: sName)
                            
                            let sBirthdate = try doc.getElementById("plnMain_lblBirthDate")?.text() ?? "N/A"
                            let sCounselor = try doc.getElementById("plnMain_lblCounselor")?.text() ?? "N/A"
                            let sBuilding = try doc.getElementById("plnMain_lblBuildingName")?.text() ?? "N/A"
                            let sGrade = try doc.getElementById("plnMain_lblGrade")?.text() ?? "N/A"
                            let sLanguage = try doc.getElementById("plnMain_lblLanguage")?.text() ?? "N/A"
                            
                            continuation.resume(returning: HACStudent(studentID: sID, studentName: sName, studentBirthdate: sBirthdate, studentCounselor: sCounselor, studentBuilding: sBuilding, studentGrade: sGrade, studentLanguage: sLanguage))
                            return
                            
                        } catch {
                            print("error in getUserInfo: \(error.localizedDescription)")
                            continuation.resume(returning: HACStudent(studentID: "", studentName: "", studentBirthdate: "", studentCounselor: "", studentBuilding: "", studentGrade: "", studentLanguage: ""))
                            return
                        }
                    }
                }
                
                task.resume()
            }
            
            return result
        }
        else {
            return nil
        }
    }
    
    //MARK: MarkingPeriod
    ///Gets the grades of each marking period
    ///Your should call this function first before anything.
    ///
    ///Returns (HACSessionStatus)
    ///(HACSessionStatus) If successfully logged in, returns passed if not, returns failed
    
    //Returns empty array if login failed
    //Returns (status, current marking period, all marking periods)
    public func availableMarkingPeriods() async -> (HACSessionStatus, String, [String], [String: String]) {
        if self.sessionAvailability == .passed {
            return await withCheckedContinuation { continuation in
                let url = URL(string: "https://\(self.url)/HomeAccess/Content/Student/Assignments.aspx")!
                var request = URLRequest(url: url)

                request.timeoutInterval = timeoutInterval
                
                let task = URLSession.shared.dataTask(with: request) {(data, res, err) in
                    guard let data = data else {
                        print("no data was returned: availableMarkingPeriods()")
                        continuation.resume(returning: (.failed, "", [], [:]))
                        return
                    }
                    
                    Task {
                        do {
                            let doc: Document = try SwiftSoup.parse(String(data: data, encoding: .utf8)!)
                            let markingPeriod = try doc.getElementById("plnMain_ddlReportCardRuns")?.children().array()
                            
                            var currentMarkingPeriod = ""
                            var allMarkingAPeriodOptions: [String] = []
                            
                            var paramDictionaryToReturn: [String: String] = [:]
                            
                            if markingPeriod?.isEmpty == false {
                                for i in 0..<(markingPeriod?.count ?? 0) {
                                    allMarkingAPeriodOptions.append(try markingPeriod?[i].attr("value") ?? "")
                                    if try markingPeriod?[i].attr("selected").isEmpty == false {
                                        currentMarkingPeriod = try markingPeriod?[i].attr("value") ?? ""
                                    }
                                }
                                
                                paramDictionaryToReturn = [
                                       "__EVENTTARGET": "ctl00$plnMain$btnRefreshView",
                                       "__EVENTARGUMENT": "",
                                       "__VIEWSTATE": try doc.getElementById("__VIEWSTATE")?.attr("value") ?? "",
                                       "__VIEWSTATEGENERATOR": "B0093F3C",
                                       "__EVENTVALIDATION": try doc.getElementById("__EVENTVALIDATION")?.attr("value") ?? "",
                                       "ctl00$plnMain$hdnValidMHACLicense": "Y",
                                       "ctl00$plnMain$hdnIsVisibleClsWrk": "N",
                                       "ctl00$plnMain$hdnIsVisibleCrsAvg": "N",
                                       "ctl00$plnMain$hdnJsAlert": "Averages cannot be displayed when Report Card Run is set to (All Runs).",
                                       "ctl00$plnMain$hdnTitle": "Classwork",
                                       "ctl00$plnMain$hdnLastUpdated": "Last Updated",
                                       "ctl00$plnMain$hdnDroppedCourse": " This course was dropped as of ",
                                       "ctl00$plnMain$hdnddlClasses": "(All Classes)",
                                       "ctl00$plnMain$hdnddlCompetencies": "(All Classes)",
                                       "ctl00$plnMain$hdnCompDateDue": "Date Due",
                                       "ctl00$plnMain$hdnCompDateAssigned": "Date Assigned",
                                       "ctl00$plnMain$hdnCompCourse": "Course",
                                       "ctl00$plnMain$hdnCompAssignment": "Assignment",
                                       "ctl00$plnMain$hdnCompAssignmentLabel": "Assignments Not Related to Any Competency",
                                       "ctl00$plnMain$hdnCompNoAssignments": "No assignments found",
                                       "ctl00$plnMain$hdnCompNoClasswork": "Classwork could not be found for this competency for the selected report card run.",
                                       "ctl00$plnMain$hdnCompScore": "Score",
                                       "ctl00$plnMain$hdnCompPoints": "Points",
                                       "ctl00$plnMain$hdnddlReportCardRuns1": "(All Runs)",
                                       "ctl00$plnMain$hdnddlReportCardRuns2": "(All Terms)",
                                       "ctl00$plnMain$hdnbtnShowAverage": "Show All Averages",
                                       "ctl00$plnMain$hdnShowAveragesToolTip": "Show all student's averages",
                                       "ctl00$plnMain$hdnPrintClassworkToolTip": "Print all classwork",
                                       "ctl00$plnMain$hdnPrintClasswork": "Print Classwork",
                                       "ctl00$plnMain$hdnCollapseToolTip": "Collapse all courses",
                                       "ctl00$plnMain$hdnCollapse": "Collapse All",
                                       "ctl00$plnMain$hdnFullToolTip": "Switch courses to Full View",
                                       "ctl00$plnMain$hdnViewFull": "Full View",
                                       "ctl00$plnMain$hdnQuickToolTip": "Switch courses to Quick View",
                                       "ctl00$plnMain$hdnViewQuick": "Quick View",
                                       "ctl00$plnMain$hdnExpand": "Expand All",
                                       "ctl00$plnMain$hdnExpandToolTip": "Expand all courses",
                                       "ctl00$plnMain$hdnChildCompetencyMessage": "This competency is calculated as an average of the following competencies",
                                       "ctl00$plnMain$hdnCompetencyScoreLabel": "Grade",
                                       "ctl00$plnMain$hdnAverageDetailsDialogTitle": "Average Details",
                                       "ctl00$plnMain$hdnAssignmentCompetency": "Assignment Competency",
                                       "ctl00$plnMain$hdnAssignmentCourse": "Assignment Course",
                                       "ctl00$plnMain$hdnTooltipTitle": "Title",
                                       "ctl00$plnMain$hdnCategory": "Category",
                                       "ctl00$plnMain$hdnDueDate": "Due Date",
                                       "ctl00$plnMain$hdnMaxPoints": "Max Points",
                                       "ctl00$plnMain$hdnCanBeDropped": "Can Be Dropped",
                                       "ctl00$plnMain$hdnHasAttachments": "Has Attachments",
                                       "ctl00$plnMain$hdnExtraCredit": "Extra Credit",
                                       "ctl00$plnMain$hdnType": "Type",
                                       "ctl00$plnMain$hdnAssignmentDataInfo": "Information could not be found for the assignment",
                                       "ctl00$plnMain$rdoViewFor" : "rdoViewForCourse",
                                       "ctl00$plnMain$ddlReportCardRuns": currentMarkingPeriod == "" ? "1-2025" : currentMarkingPeriod,
                                       "ctl00$plnMain$ddlClasses": "ALL",
                                       "ctl00$plnMain$ddlCompetencies": "ALL",
                                       "ctl00$plnMain$ddlOrderBy": "Class"
                                   ]
                                
                            }
                            else {
                                print("Marking period was empty, try logging in first using: login()")
                                continuation.resume(returning: (.failed, "", [], [:]))
                                return
                            }
                            
                            continuation.resume(returning: (.passed, currentMarkingPeriod, allMarkingAPeriodOptions, paramDictionaryToReturn))
                            return
                            
                        } catch {
                            print("Could not get availableMarkingPeriods: \(error)")
                            continuation.resume(returning: (.failed, "", [], [:]))
                            return
                        }
                    }
                }
                
                task.resume()
            }
        }
        else {
            print("Login was not passed, therefore will not run availableMarkingPeriods()")
            return (.failed, "", [], [:])
        }
    }
    
    public func availableMarkingPeriodsWithCurrentMarkingPeriod(districtWeightIdentifier: String) async -> (HACSessionStatus, String, [String], [String: String], MarkingPeriod?) {
        if self.sessionAvailability == .passed {
            let result: (HACSessionStatus, String, [String], [String: String], MarkingPeriod?) = await withCheckedContinuation { continuation in
                let url = URL(string: "https://\(self.url)/HomeAccess/Content/Student/Assignments.aspx")!
                var request = URLRequest(url: url)

                request.timeoutInterval = timeoutInterval
                
                let task = URLSession.shared.dataTask(with: request) {(data, res, err) in
                    guard let data = data else {
                        print("no data was returned: availableMarkingPeriods()")
                        continuation.resume(returning: (.failed, "", [], [:], nil))
                        return
                    }
                    
                    Task {
                        do {
                            let doc: Document = try SwiftSoup.parse(String(data: data, encoding: .utf8)!)
                            let markingPeriod = try doc.getElementById("plnMain_ddlReportCardRuns")?.children().array()
                            
                            var currentMarkingPeriod = ""
                            var allMarkingAPeriodOptions: [String] = []
                            
                            var paramDictionaryToReturn: [String: String] = [:]
                            
                            var markingPeriodClasses: [Class] = []
                            
                            if markingPeriod?.isEmpty == false {
                                for i in 0..<(markingPeriod?.count ?? 0) {
                                    allMarkingAPeriodOptions.append(try markingPeriod?[i].attr("value") ?? "")
                                    if try markingPeriod?[i].attr("selected").isEmpty == false {
                                        currentMarkingPeriod = try markingPeriod?[i].attr("value") ?? ""
                                    }
                                }
                                
                                paramDictionaryToReturn = [
                                       "__EVENTTARGET": "ctl00$plnMain$btnRefreshView",
                                       "__EVENTARGUMENT": "",
                                       "__VIEWSTATE": try doc.getElementById("__VIEWSTATE")?.attr("value") ?? "",
                                       "__VIEWSTATEGENERATOR": "B0093F3C",
                                       "__EVENTVALIDATION": try doc.getElementById("__EVENTVALIDATION")?.attr("value") ?? "",
                                       "ctl00$plnMain$hdnValidMHACLicense": "Y",
                                       "ctl00$plnMain$hdnIsVisibleClsWrk": "N",
                                       "ctl00$plnMain$hdnIsVisibleCrsAvg": "N",
                                       "ctl00$plnMain$hdnJsAlert": "Averages cannot be displayed when Report Card Run is set to (All Runs).",
                                       "ctl00$plnMain$hdnTitle": "Classwork",
                                       "ctl00$plnMain$hdnLastUpdated": "Last Updated",
                                       "ctl00$plnMain$hdnDroppedCourse": " This course was dropped as of ",
                                       "ctl00$plnMain$hdnddlClasses": "(All Classes)",
                                       "ctl00$plnMain$hdnddlCompetencies": "(All Classes)",
                                       "ctl00$plnMain$hdnCompDateDue": "Date Due",
                                       "ctl00$plnMain$hdnCompDateAssigned": "Date Assigned",
                                       "ctl00$plnMain$hdnCompCourse": "Course",
                                       "ctl00$plnMain$hdnCompAssignment": "Assignment",
                                       "ctl00$plnMain$hdnCompAssignmentLabel": "Assignments Not Related to Any Competency",
                                       "ctl00$plnMain$hdnCompNoAssignments": "No assignments found",
                                       "ctl00$plnMain$hdnCompNoClasswork": "Classwork could not be found for this competency for the selected report card run.",
                                       "ctl00$plnMain$hdnCompScore": "Score",
                                       "ctl00$plnMain$hdnCompPoints": "Points",
                                       "ctl00$plnMain$hdnddlReportCardRuns1": "(All Runs)",
                                       "ctl00$plnMain$hdnddlReportCardRuns2": "(All Terms)",
                                       "ctl00$plnMain$hdnbtnShowAverage": "Show All Averages",
                                       "ctl00$plnMain$hdnShowAveragesToolTip": "Show all student's averages",
                                       "ctl00$plnMain$hdnPrintClassworkToolTip": "Print all classwork",
                                       "ctl00$plnMain$hdnPrintClasswork": "Print Classwork",
                                       "ctl00$plnMain$hdnCollapseToolTip": "Collapse all courses",
                                       "ctl00$plnMain$hdnCollapse": "Collapse All",
                                       "ctl00$plnMain$hdnFullToolTip": "Switch courses to Full View",
                                       "ctl00$plnMain$hdnViewFull": "Full View",
                                       "ctl00$plnMain$hdnQuickToolTip": "Switch courses to Quick View",
                                       "ctl00$plnMain$hdnViewQuick": "Quick View",
                                       "ctl00$plnMain$hdnExpand": "Expand All",
                                       "ctl00$plnMain$hdnExpandToolTip": "Expand all courses",
                                       "ctl00$plnMain$hdnChildCompetencyMessage": "This competency is calculated as an average of the following competencies",
                                       "ctl00$plnMain$hdnCompetencyScoreLabel": "Grade",
                                       "ctl00$plnMain$hdnAverageDetailsDialogTitle": "Average Details",
                                       "ctl00$plnMain$hdnAssignmentCompetency": "Assignment Competency",
                                       "ctl00$plnMain$hdnAssignmentCourse": "Assignment Course",
                                       "ctl00$plnMain$hdnTooltipTitle": "Title",
                                       "ctl00$plnMain$hdnCategory": "Category",
                                       "ctl00$plnMain$hdnDueDate": "Due Date",
                                       "ctl00$plnMain$hdnMaxPoints": "Max Points",
                                       "ctl00$plnMain$hdnCanBeDropped": "Can Be Dropped",
                                       "ctl00$plnMain$hdnHasAttachments": "Has Attachments",
                                       "ctl00$plnMain$hdnExtraCredit": "Extra Credit",
                                       "ctl00$plnMain$hdnType": "Type",
                                       "ctl00$plnMain$hdnAssignmentDataInfo": "Information could not be found for the assignment",
                                       "ctl00$plnMain$rdoViewFor" : "rdoViewForCourse",
                                       "ctl00$plnMain$ddlReportCardRuns": currentMarkingPeriod == "" ? "1-2025" : currentMarkingPeriod,
                                       "ctl00$plnMain$ddlClasses": "ALL",
                                       "ctl00$plnMain$ddlCompetencies": "ALL",
                                       "ctl00$plnMain$ddlOrderBy": "Class"
                                   ]
                                
                                let course_container = try doc.getElementsByClass("AssignmentClass")
                                
                                if course_container.isEmpty() {
                                    print("could not get grades")
                                    continuation.resume(returning: (.failed, "", [], [:], nil))
                                    return
                                }
                                
                                for (index, container) in course_container.enumerated() {
                                    do {
                                        print("entered container")
                                        
                                        //Class Name
                                        var nameContainer = try container.getElementsByTag("a").first()?.text().split(separator: " ") ?? ["", "", "", "Error"]
                                        nameContainer.removeSubrange(0...2)
                                        let className = nameContainer.joined(separator: " ")
                                        
                                        //Class Grade
                                        var classGrade = ""
                                        let classGradeContainer = try container.getElementById("plnMain_rptAssigmnetsByCourse_lblHdrAverage_\(index)")?.text()
                                        if ((classGradeContainer?.isEmpty) == nil) {
                                            classGrade = "N/A"
                                        }
                                        else {
                                            let splitGrade = classGradeContainer?.split(separator: " ")
                                            let parsed = splitGrade?.last
                                            classGrade = parsed?.replacingOccurrences(of: "%", with: "") ?? "N/A"
                                        }
                                        
                                        //Class Assignments
                                        var classAssignments: [Assignment] = []
                                        
                                        let assignmentsContainer = try container.getElementById("plnMain_rptAssigmnetsByCourse_dgCourseAssignments_\(index)")?.getElementsByClass("sg-asp-table-data-row").array() ?? []
                                        
                                        for assignment in assignmentsContainer {
                                            let specificAssignment = try assignment.getElementsByTag("td").array()
                                            print("specificAssignment: \(specificAssignment)")
                                            
                                            var dateDue = ""
                                            var dateAssigned = ""
                                            var name = ""
                                            var category = ""
                                            var score = ""
                                            var totalPoints = ""
                                            var weight = ""
                                            var weightedScore = ""
                                            var weightedTotalPoints = ""
                                            
                                            if specificAssignment.count > 8 {
                                                dateDue = try specificAssignment[0].text()
                                                dateAssigned = try specificAssignment[1].text()
                                                name = try specificAssignment[2].getElementsByTag("a").text()
                                                category = try specificAssignment[3].text()
                                                score = try specificAssignment[4].text()
                                                totalPoints = try specificAssignment[5].text()
                                                weight = try specificAssignment[6].text()
                                                weightedScore = try specificAssignment[7].text()
                                                weightedTotalPoints = try specificAssignment[8].text()
                                            }

                                            if category == " " || category.isEmpty {
                                                category = "N/A"
                                            }
                                            
                                            if score == " " || score.isEmpty {
                                                score = "N/A"
                                            }
                                            
                                            if dateAssigned == "&nbsp" {
                                                dateAssigned = "N/A"
                                            }
                                            
                                            if dateDue == "&nbsp" {
                                                dateDue = "N/A"
                                            }
                                            
                                            if try specificAssignment[2].getElementsByTag("strike").isEmpty() {
                                                classAssignments.append(Assignment(
                                                    dateDue: dateDue,
                                                    dateAssigned: dateAssigned,
                                                    name: name,
                                                    category: category,
                                                    score: score,
                                                    totalPoints: totalPoints,
                                                    weight: weight,
                                                    weightedScore: weightedScore,
                                                    weightedTotalPoints: weightedTotalPoints,
                                                    strikeThrough: false,
                                                    custom: false
                                                ))
                                            }
                                            else {
                                                classAssignments.append(Assignment(
                                                    dateDue: dateDue,
                                                    dateAssigned: dateAssigned,
                                                    name: name,
                                                    category: category,
                                                    score: score,
                                                    totalPoints: totalPoints,
                                                    weight: weight,
                                                    weightedScore: weightedScore,
                                                    weightedTotalPoints: weightedTotalPoints,
                                                    strikeThrough: true,
                                                    custom: false
                                                ))
                                            }
                                        }
                                        
                                        //Class Category & Category Weights
                                        var categoryWeights: [String : [String : String]] = [:]
                                        
                                        let categoriesContainer = try container.getElementById("plnMain_rptAssigmnetsByCourse_dgCourseCategories_\(index)")
                                        let categories = try categoriesContainer?.getElementsByClass("sg-asp-table-data-row").array() ?? []
                                        
                                        for category in categories {
                                            let specificCategory = try category.getElementsByTag("td").array()
                                            categoryWeights[try specificCategory[0].text()] = [
                                                "studentPoints" : try specificCategory[1].text(),
                                                "maximumPoints" : try specificCategory[2].text(),
                                                "categoryWeight" : try specificCategory[4].text()
                                            ]
                                        }
                                        
                                        print("categoryWeights: \(categoryWeights)")
                                        
                                        var showNoticeForMissingCategoryWeight = false
                                        
                                        for assignment in classAssignments {
                                            if categoryWeights[assignment.category] == nil {
                                                categoryWeights[assignment.category] = [
                                                    "studentPoints" : "100",
                                                    "maximumPoints" : "100",
                                                    "categoryWeight" : "0",
                                                    "missingCategoryWeight": "YES"
                                                ]
                                                showNoticeForMissingCategoryWeight = true
                                            }
                                        }
                                        
                                        if showNoticeForMissingCategoryWeight {
                                            //Toast(message: ToasterAlert(alertSeverity: 1, message: "Unable to get assignment weights for \(className). Predictions occuring within the class will temporarily be disabled until HAC provides the required data."))
                                            print("did not receive all category weights, however will not notify")
                                        }
                                        else {
                                            print("all categories accounted for \(className)")
                                        }
                                        
                                        let weight = await HACDistrictWeightManager.shared.weight(for: districtWeightIdentifier, className: className)
                                        let credit = 0.5
                                        
                                        let tempClass = Class(name: className, score: classGrade, weight: weight, credits: credit, assignments: classAssignments, categories: categoryWeights)
                                        markingPeriodClasses.append(tempClass)
                                        
                                    } catch {
                                        print("Something went wrong: ac loop parsing")
                                    }
                                }
                                
                            }
                            else {
                                print("Marking period was empty, try logging in first using: login()")
                                continuation.resume(returning: (.failed, "", [], [:], nil))
                                return
                            }
                            
                            continuation.resume(returning: (.passed, currentMarkingPeriod, allMarkingAPeriodOptions, paramDictionaryToReturn, MarkingPeriod(period: currentMarkingPeriod, classes: markingPeriodClasses)))
                            return
                            
                        } catch {
                            print("Could not get availableMarkingPeriods: \(error)")
                            continuation.resume(returning: (.failed, "", [], [:], nil))
                            return
                        }
                    }
                }
                
                task.resume()
            }
            
            if result.4 != nil {
                if useAnimation {
                    withAnimation(Animation.bouncy(duration: 0.3)) {
                        markingPeriods.append(result.4 ?? MarkingPeriod(period: "Error", classes: []))
                    }
                }
                else {
                    markingPeriods.append(result.4 ?? MarkingPeriod(period: "Error", classes: []))
                }
            }
            
            return (result.0, result.1, result.2, result.3, result.4)
        }
        else {
            print("Login was not passed, therefore will not run availableMarkingPeriods()")
            return (.failed, "", [], [:], nil)
        }
    }
    
    //Requires a value from availableMarkingPeriods()
    //Returns (status, marking period)
    public func requestGrades(districtWeightIdentifier: String, forPeriod: String, dictionary: [String: String]) async -> (HACSessionStatus) {
        if self.sessionAvailability == .passed {
            let result: (HACSessionStatus, MarkingPeriod) =  await withCheckedContinuation { continuation in
                let url = URL(string: "https://\(self.url)/HomeAccess/Content/Student/Assignments.aspx")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"

                request.timeoutInterval = timeoutInterval
                
                var newDictionary = dictionary
                newDictionary["ctl00$plnMain$ddlReportCardRuns"] = forPeriod
                request.httpBody = newDictionary.percentEncoded()
                
                let task = URLSession.shared.dataTask(with: request) {(data, res, err) in
                    guard let data = data else {
                        print("no data was returned: requestGrades()")
                        continuation.resume(returning: (.failed, MarkingPeriod(period: "", classes: [])))
                        return
                    }
                    
                    Task {
                        do {
                            let doc: Document = try SwiftSoup.parse(String(data: data, encoding: .utf8)!)
                            
                            let course_container = try doc.getElementsByClass("AssignmentClass")
                            
                            if course_container.isEmpty() {
                                print("could not get grades")
                                continuation.resume(returning: (.failed, MarkingPeriod(period: "", classes: [])))
                                return
                            }
                            
                            var markingPeriodClasses: [Class] = []
                            
                            for (index, container) in course_container.enumerated() {
                                do {
                                    print("entered container")
                                    
                                    //Class Name
                                    var nameContainer = try container.getElementsByTag("a").first()?.text().split(separator: " ") ?? ["", "", "", "Error"]
                                    nameContainer.removeSubrange(0...2)
                                    let className = nameContainer.joined(separator: " ")
                                    
                                    //Class Grade
                                    var classGrade = ""
                                    let classGradeContainer = try container.getElementById("plnMain_rptAssigmnetsByCourse_lblHdrAverage_\(index)")?.text()
                                    if ((classGradeContainer?.isEmpty) == nil) {
                                        classGrade = "N/A"
                                    }
                                    else {
                                        let splitGrade = classGradeContainer?.split(separator: " ")
                                        let parsed = splitGrade?.last
                                        classGrade = parsed?.replacingOccurrences(of: "%", with: "") ?? "N/A"
                                    }
                                    
                                    //Class Assignments
                                    var classAssignments: [Assignment] = []
                                    
                                    let assignmentsContainer = try container.getElementById("plnMain_rptAssigmnetsByCourse_dgCourseAssignments_\(index)")?.getElementsByClass("sg-asp-table-data-row").array() ?? []
                                    
                                    for assignment in assignmentsContainer {
                                        let specificAssignment = try assignment.getElementsByTag("td").array()
                                        print("specificAssignment: \(specificAssignment)")
                                        
                                        var dateDue = ""
                                        var dateAssigned = ""
                                        var name = ""
                                        var category = ""
                                        var score = ""
                                        var totalPoints = ""
                                        var weight = ""
                                        var weightedScore = ""
                                        var weightedTotalPoints = ""
                                        
                                        if specificAssignment.count > 8 {
                                            dateDue = try specificAssignment[0].text()
                                            dateAssigned = try specificAssignment[1].text()
                                            name = try specificAssignment[2].getElementsByTag("a").text()
                                            category = try specificAssignment[3].text()
                                            score = try specificAssignment[4].text()
                                            totalPoints = try specificAssignment[5].text()
                                            weight = try specificAssignment[6].text()
                                            weightedScore = try specificAssignment[7].text()
                                            weightedTotalPoints = try specificAssignment[8].text()
                                        }

                                        if category == " " || category.isEmpty {
                                            category = "N/A"
                                        }
                                        
                                        if score == " " || score.isEmpty {
                                            score = "N/A"
                                        }
                                        
                                        if dateAssigned == "&nbsp" {
                                            dateAssigned = "N/A"
                                        }
                                        
                                        if dateDue == "&nbsp" {
                                            dateDue = "N/A"
                                        }
                                        
                                        if try specificAssignment[2].getElementsByTag("strike").isEmpty() {
                                            classAssignments.append(Assignment(
                                                dateDue: dateDue,
                                                dateAssigned: dateAssigned,
                                                name: name,
                                                category: category,
                                                score: score,
                                                totalPoints: totalPoints,
                                                weight: weight,
                                                weightedScore: weightedScore,
                                                weightedTotalPoints: weightedTotalPoints,
                                                strikeThrough: false,
                                                custom: false
                                            ))
                                        }
                                        else {
                                            classAssignments.append(Assignment(
                                                dateDue: dateDue,
                                                dateAssigned: dateAssigned,
                                                name: name,
                                                category: category,
                                                score: score,
                                                totalPoints: totalPoints,
                                                weight: weight,
                                                weightedScore: weightedScore,
                                                weightedTotalPoints: weightedTotalPoints,
                                                strikeThrough: true,
                                                custom: false
                                            ))
                                        }
                                    }
                                    
                                    //Class Category & Category Weights
                                    var categoryWeights: [String : [String : String]] = [:]
                                    
                                    let categoriesContainer = try container.getElementById("plnMain_rptAssigmnetsByCourse_dgCourseCategories_\(index)")
                                    let categories = try categoriesContainer?.getElementsByClass("sg-asp-table-data-row").array() ?? []
                                    
                                    for category in categories {
                                        let specificCategory = try category.getElementsByTag("td").array()
                                        categoryWeights[try specificCategory[0].text()] = [
                                            "studentPoints" : try specificCategory[1].text(),
                                            "maximumPoints" : try specificCategory[2].text(),
                                            "categoryWeight" : try specificCategory[4].text()
                                        ]
                                    }
                                    
                                    print("categoryWeights: \(categoryWeights)")
                                    
                                    var showNoticeForMissingCategoryWeight = false
                                    
                                    for assignment in classAssignments {
                                        if categoryWeights[assignment.category] == nil {
                                            categoryWeights[assignment.category] = [
                                                "studentPoints" : "100",
                                                "maximumPoints" : "100",
                                                "categoryWeight" : "0",
                                                "missingCategoryWeight": "YES"
                                            ]
                                            showNoticeForMissingCategoryWeight = true
                                        }
                                    }
                                    
                                    if showNoticeForMissingCategoryWeight {
                                        //Toast(message: ToasterAlert(alertSeverity: 1, message: "Unable to get assignment weights for \(className). Predictions occuring within the class will temporarily be disabled until HAC provides the required data."))
                                        print("did not receive all category weights, however will not notify")
                                    }
                                    else {
                                        print("all categories accounted for \(className)")
                                    }
                                    
                                    let weight = await HACDistrictWeightManager.shared.weight(for: districtWeightIdentifier, className: className)
                                    let credit = 0.5
                                    
                                    let tempClass = Class(name: className, score: classGrade, weight: weight, credits: credit, assignments: classAssignments, categories: categoryWeights)
                                    markingPeriodClasses.append(tempClass)
                                    
                                } catch {
                                    print("Something went wrong: ac loop parsing")
                                }
                            }
                            
                            let returnableMarkingPeriod = MarkingPeriod(period: forPeriod, classes: markingPeriodClasses)
                            
                            continuation.resume(returning: (.passed, returnableMarkingPeriod))
                            return
                            
                        } catch {
                            print("Could not requestGrades(): \(error)")
                            continuation.resume(returning: (.failed, MarkingPeriod(period: "", classes: [])))
                            return
                        }
                    }
                }
                
                task.resume()
            }
            if result.0 == .passed {
                if useAnimation {
                    withAnimation(Animation.bouncy(duration: 0.3)) {
                        markingPeriods.append(result.1)
                    }
                }
                else {
                    markingPeriods.append(result.1)
                }
                return (result.0)
            }
            else {
                print("Could not requestGrades for \(forPeriod)")
                return (.failed)
            }
        }
        else {
            print("Login was not passed, therefore will not run requestGrades()")
            return (.failed)
        }
    }
}

//MARK: Extensions
///Essential for url requests param encoding
extension Dictionary {
    func percentEncoded() -> Data? {
        map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowed: CharacterSet = .urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}
