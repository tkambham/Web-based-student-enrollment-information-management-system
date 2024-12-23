drop table usersession cascade constraints;
drop table studentuser cascade constraints;
drop table adminuser cascade constraints;
drop table graduateStudent cascade constraints;
drop table underGraduateStudent cascade constraints;
drop table enroll cascade constraints;
drop table prerequisiteCourse cascade constraints;
drop table section cascade constraints;
drop table course;
drop table usertable;

-- Creating user tables and session table
CREATE TABLE usertable (
    username VARCHAR2(20) PRIMARY KEY,
    password VARCHAR2(12) NOT NULL,
    firstname VARCHAR2(20) NOT NULL,
    lastname VARCHAR2(20) NOT NULL,
    usertype VARCHAR2(12) NOT NULL
);


CREATE TABLE usersession (
    sessionid VARCHAR2(32) PRIMARY KEY,
    username VARCHAR2(20) NOT NULL,
    sessiondate DATE,
    FOREIGN KEY (username) REFERENCES usertable(username)
);

-- Creating two user tables for admin and student
CREATE TABLE adminuser (
    username VARCHAR2(20) PRIMARY KEY,
    startdate DATE NOT NULL,
    FOREIGN KEY (username) REFERENCES usertable(username) ON DELETE CASCADE
);

CREATE TABLE studentuser (
    studentID VARCHAR2(8) PRIMARY KEY,
    age NUMBER(2) NOT NULL,
    address VARCHAR2(50) NOT NULL,
    studenttype VARCHAR2(13) NOT NULL,
    status VARCHAR2(1) NOT NULL,
    username VARCHAR2(20) NOT NULL,
    admissiondate DATE NOT NULL,
    FOREIGN KEY (username) REFERENCES usertable(username) ON DELETE CASCADE
);

-- Creating two tables for graduate and undergraduate students
CREATE TABLE graduateStudent (
    studentID VARCHAR2(8) PRIMARY KEY,
    concentration VARCHAR2(20) NOT NULL,
    FOREIGN KEY (studentID) REFERENCES studentuser(studentID) ON DELETE CASCADE
);

CREATE TABLE underGraduateStudent (
    studentID VARCHAR2(8) PRIMARY KEY,
    standing VARCHAR2(20) NOT NULL,
    FOREIGN KEY (studentID) REFERENCES studentuser(studentID) ON DELETE CASCADE
);

-- Creating course, section, enroll, and prerequisiteCourse tables
CREATE TABLE course (
    coursenumber NUMBER PRIMARY KEY,
    courseTitle VARCHAR2(35) NOT NULL,
    creditHours NUMBER(1) NOT NULL
);

CREATE TABLE section (
    sectionID VARCHAR2(6) PRIMARY KEY,
    coursenumber NUMBER NOT NULL,
    schedule VARCHAR2(20) NOT NULL,
    semester VARCHAR2(20) NOT NULL,
    enrollmentDeadline DATE NOT NULL,
    capacity NUMBER(3) NOT NULL,
    seatsAvailable NUMBER(3) DEFAULT NULL,
    FOREIGN KEY (coursenumber) REFERENCES course(coursenumber) ON DELETE CASCADE
);

CREATE TABLE enroll (
    studentID VARCHAR2(8) NOT NULL,
    sectionID VARCHAR2(6) NOT NULL,
    grade VARCHAR2(1),
    PRIMARY KEY (studentID, sectionID),
    FOREIGN KEY (studentID) REFERENCES studentuser(studentID) ON DELETE CASCADE,
    FOREIGN KEY (sectionID) REFERENCES section(sectionID) ON DELETE CASCADE
);

CREATE TABLE prerequisiteCourse (
    coursenumber NUMBER NOT NULL,
    prerequisitecoursenumber NUMBER NOT NULL,
    PRIMARY KEY (coursenumber, prerequisitecoursenumber),
    FOREIGN KEY (coursenumber) REFERENCES course(coursenumber) ON DELETE CASCADE,
    FOREIGN KEY (prerequisitecoursenumber) REFERENCES course(coursenumber) ON DELETE CASCADE
);

-- View to display student information
CREATE OR REPLACE VIEW studentview AS 
SELECT usertable.username, 
        usertable.firstname, 
        usertable.lastname, 
        usertable.usertype, 
        usersession.sessionid, 
        studentuser.studentID, 
        studentuser.age, 
        studentuser.address, 
        studentuser.studenttype, 
        studentuser.status, 
        studentuser.admissiondate
    FROM usertable
    JOIN usersession ON usertable.username = usersession.username
    JOIN studentuser ON usertable.username = studentuser.username;

-- Trigger to add seatsAvailable to section table
CREATE OR REPLACE TRIGGER add_seats_available
BEFORE INSERT ON section
FOR EACH ROW
WHEN (new.seatsAvailable IS NULL)
BEGIN
    :new.seatsAvailable := :new.capacity;
END;
/

-- Triggers to update seatsAvailable in section table
CREATE OR REPLACE TRIGGER insert_seats_available
BEFORE INSERT ON enroll
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        UPDATE section SET seatsAvailable = seatsAvailable - 1 WHERE sectionID = :new.sectionID;
    END IF;
END;
/

-- Trigger to delete seatsAvailable from section table 
CREATE OR REPLACE TRIGGER delete_seats_available
AFTER DELETE ON enroll
FOR EACH ROW
BEGIN
    IF DELETING THEN
        UPDATE section SET seatsAvailable = seatsAvailable + 1 WHERE sectionID = :old.sectionID;
    END IF;
END;
/

-- Procedures to create studentID and get probation status
CREATE OR REPLACE PROCEDURE create_student_id(
    lastname IN VARCHAR2,
    studentID OUT VARCHAR2
)
AS
    v_initials VARCHAR2(2);
    v_number_part NUMBER;
    v_count NUMBER;
BEGIN
    v_initials := UPPER(SUBSTR(lastname, 1, 2));

    SELECT COUNT(studentID) INTO v_count FROM studentuser;

    v_number_part := v_count + 123456;

    studentID := v_initials || TO_CHAR(v_number_part);

  DBMS_OUTPUT.PUT_LINE('Generated studentID: ' || studentID);
END;
/
SHOW ERRORS;

-- Procedure to get probation status
CREATE OR REPLACE PROCEDURE get_probation_status(
    p_studentID IN VARCHAR2
)
IS
    gps_gpa NUMBER(3,2);
    gps_course_count NUMBER(3);
BEGIN
    SELECT ROUND(SUM(
            CASE 
                WHEN e.grade = 'A' THEN 4 * c.creditHours
                WHEN e.grade = 'B' THEN 3 * c.creditHours
                WHEN e.grade = 'C' THEN 2 * c.creditHours
                WHEN e.grade = 'D' THEN 1 * c.creditHours
                WHEN e.grade = 'F' THEN 0 * c.creditHours
                ELSE 0
            END
        ) / 
        NULLIF(SUM(
            CASE 
                WHEN e.grade IN ('A', 'B', 'C', 'D', 'F') THEN c.creditHours
                ELSE 0
            END
        ), 0), 2) INTO gps_gpa
    FROM studentview sv
    LEFT JOIN enroll e ON sv.studentID = e.studentID
    LEFT JOIN section s ON e.sectionID = s.sectionID
    LEFT JOIN course c ON s.coursenumber = c.coursenumber
    WHERE sv.studentID = p_studentID;


    SELECT COUNT(DISTINCT c.coursenumber) INTO gps_course_count
    FROM studentview sv
    LEFT JOIN enroll e ON sv.studentID = e.studentID
    LEFT JOIN section s ON e.sectionID = s.sectionID
    LEFT JOIN course c ON s.coursenumber = c.coursenumber
    WHERE sv.studentID = p_studentID
    AND e.grade IS NOT NULL;

    IF gps_gpa = 0.0 AND gps_course_count = 0 THEN
        UPDATE studentuser su SET su.status = 'N' WHERE su.studentID = p_studentID;
    ELSIF gps_gpa = 2.0 AND gps_course_count != 0 THEN
        UPDATE studentuser su SET su.status = 'P' WHERE su.studentID = p_studentID;
    ELSIF gps_gpa < 2.0 THEN
        UPDATE studentuser su SET su.status = 'P' WHERE su.studentID = p_studentID;
    ELSE
        UPDATE studentuser su SET su.status = 'N' WHERE su.studentID = p_studentID;
    END IF;
END get_probation_status;
/
SHOW ERRORS;

COMMIT;


-- Adding data to the tables
INSERT INTO usertable VALUES ('jdeep', '1234', 'Jane', 'Deep', 'admin');
INSERT INTO usertable VALUES ('ssmith', '2345', 'Steven', 'Smith', 'studentadmin');
INSERT INTO usertable VALUES ('llivingstone', '3456', 'Liam', 'Livingstone', 'student');
INSERT INTO usertable VALUES ('dwarner', '4567', 'David', 'Warner', 'student');
INSERT INTO usertable VALUES ('mlabuschagne', '5678', 'Marnus', 'Labuschagne', 'student');


INSERT INTO adminuser VALUES ('jdeep', to_date('07/25/2023', 'mm/dd/yyyy'));
INSERT INTO studentuser VALUES ('LI123456','22','20 S Bryant Ave, Edmond, OK 73034','Undergraduate','N','llivingstone', to_date('08/15/2023', 'mm/dd/yyyy'));
INSERT INTO studentuser VALUES ('SM123457','25','320 E Edwards, Edmond, OK 73034','Graduate','N','ssmith', to_date('01/15/2024', 'mm/dd/yyyy'));
INSERT INTO adminuser VALUES ('ssmith', to_date('08/11/2024', 'mm/dd/yyyy'));
INSERT INTO studentuser VALUES ('WA123458','23','100 W Campbell St, Edmond, OK 73034','Undergraduate','N','dwarner', to_date('08/15/2023', 'mm/dd/yyyy'));
INSERT INTO studentuser VALUES ('LA123459','24','200 N Fretz Ave, Edmond, OK 73034','Graduate','N','mlabuschagne', to_date('01/15/2024', 'mm/dd/yyyy'));


INSERT INTO underGraduateStudent VALUES ('LI123456','Junior');
INSERT INTO graduateStudent VALUES ('SM123457','Intelligent Systems');
INSERT INTO underGraduateStudent VALUES ('WA123458','Senior');
INSERT INTO graduateStudent VALUES ('LA123459','Full Stack');


INSERT INTO course VALUES ('1001', 'Algo Design and Implementation', '3');
INSERT INTO course VALUES ('1002', 'Data Structures', '3');
INSERT INTO course VALUES ('1101', 'Database Management', '3');
INSERT INTO course VALUES ('1201', 'Operating Systems', '3');
INSERT INTO course VALUES ('1202', 'Computer Networks', '3');
INSERT INTO course VALUES ('1301', 'Software Engineering I', '3');
INSERT INTO course VALUES ('1302', 'Software Engineering II', '3');
INSERT INTO course VALUES ('1401', 'Graduate Project', '3');
INSERT INTO course VALUES ('1402', 'Thesis', '6');
INSERT INTO course VALUES ('1501', 'Front End Web Development', '3');
INSERT INTO course VALUES ('1502', 'Cloud Web Apps Development', '3');
INSERT INTO course VALUES ('1503', 'Mobile Apps Development', '3');
INSERT INTO course VALUES ('1601', 'Concepts of AI', '3');
INSERT INTO course VALUES ('1602', 'Algos of Machine Learning', '3');
INSERT INTO course VALUES ('1603', 'Computer Application in Statistics', '3');
INSERT INTO course VALUES ('1604', 'Introduction to Robotics', '3');

INSERT INTO prerequisiteCourse VALUES ('1602', '1603');
INSERT INTO prerequisiteCourse VALUES ('1604', '1603');
INSERT INTO prerequisiteCourse VALUES ('1604', '1602');
INSERT INTO prerequisiteCourse VALUES ('1604', '1601');
INSERT INTO prerequisiteCourse VALUES ('1302', '1301');
INSERT INTO prerequisiteCourse VALUES ('1502', '1501');
INSERT INTO prerequisiteCourse VALUES ('1503', '1501');
INSERT INTO prerequisiteCourse VALUES ('1202', '1201');

INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('23S101', '1001', 'MWF 10:00-11:00', 'Fall 2023', to_date('08/15/2023', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('23S102', '1002', 'MWF 08:00-09:00', 'Fall 2023', to_date('08/15/2023', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('23S103', '1101', 'MWF 13:00-14:00', 'Fall 2023', to_date('08/15/2023', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('23S104', '1201', 'MW 16:00-17:30', 'Fall 2023', to_date('08/15/2023', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('23S105', '1202', 'TR 09:00-10:30', 'Fall 2023', to_date('08/15/2023', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('23S106', '1301', 'MWF 09:00-10:00', 'Fall 2023', to_date('08/15/2023', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('23S107', '1302', 'TR 10:00-11:30', 'Fall 2023', to_date('08/15/2023', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('23S109', '1402', 'W 14:00-16:00', 'Fall 2023', to_date('08/15/2023', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('23S110', '1501', 'TR 12:00-13:30', 'Fall 2023', to_date('08/15/2023', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('23S112', '1503', 'MWF 15:00-16:00', 'Fall 2023', to_date('08/15/2023', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('23S114', '1602', 'TR 08:30-10:00', 'Fall 2023', to_date('08/15/2023', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('23S115', '1603', 'MWF 09:30-10:30', 'Fall 2023', to_date('08/15/2023', 'mm/dd/yyyy'), 40);

INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S201', '1001', 'TF 09:00-10:30', 'Spring 2024', to_date('01/15/2024', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S202', '1002', 'MW 10:30-12:00', 'Spring 2024', to_date('01/15/2024', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S203', '1101', 'TF 12:00-13:30', 'Spring 2024', to_date('01/15/2024', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S204', '1201', 'MWF 08:00-09:00', 'Spring 2024', to_date('01/15/2024', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S205', '1202', 'MW 14:00-15:30', 'Spring 2024', to_date('01/15/2024', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S206', '1301', 'TF 10:00-11:30', 'Spring 2024', to_date('01/15/2024', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S209', '1402', 'W 14:00-16:00', 'Spring 2024', to_date('01/15/2024', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S210', '1501', 'TR 08:00-09:30', 'Spring 2024', to_date('01/15/2024', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S211', '1502', 'MWF 11:00-12:00', 'Spring 2024', to_date('01/15/2024', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S213', '1601', 'MW 12:00-13:30', 'Spring 2024', to_date('01/15/2024', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S116', '1604', 'TF 14:00-15:30', 'Spring 2024', to_date('01/15/2024', 'mm/dd/yyyy'), 35);

INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S302', '1002', 'MTr 09:00-10:30', 'Summer 2024', to_date('06/01/2024', 'mm/dd/yyyy'), 20);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S310', '1501', 'TF 11:00-12:30', 'Summer 2024', to_date('06/01/2024', 'mm/dd/yyyy'), 20);


INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S101', '1001', 'MWF 10:00-11:00', 'Fall 2024', to_date('08/15/2024', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S102', '1002', 'MWF 08:00-09:00', 'Fall 2024', to_date('08/15/2024', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S103', '1101', 'MWF 13:00-14:00', 'Fall 2024', to_date('08/15/2024', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S104', '1201', 'MW 16:00-17:30', 'Fall 2024', to_date('08/15/2024', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S105', '1202', 'TR 09:00-10:30', 'Fall 2024', to_date('08/15/2024', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S106', '1301', 'MWF 09:00-10:00', 'Fall 2024', to_date('08/15/2024', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S107', '1302', 'TR 10:00-11:30', 'Fall 2024', to_date('08/15/2024', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S109', '1402', 'W 14:00-16:00', 'Fall 2024', to_date('08/15/2024', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S110', '1501', 'TR 12:00-13:30', 'Fall 2024', to_date('08/15/2024', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S112', '1503', 'MWF 15:00-16:00', 'Fall 2024', to_date('08/15/2024', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S114', '1602', 'TR 08:30-10:00', 'Fall 2024', to_date('08/15/2024', 'mm/dd/yyyy'), 40);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('24S115', '1603', 'MWF 09:30-10:30', 'Fall 2024', to_date('08/15/2024', 'mm/dd/yyyy'), 40);

INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('25S201', '1001', 'TF 09:00-10:30', 'Spring 2025', to_date('01/15/2025', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('25S202', '1002', 'MW 10:30-12:00', 'Spring 2025', to_date('01/15/2025', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('25S203', '1101', 'TF 12:00-13:30', 'Spring 2025', to_date('01/15/2025', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('25S204', '1201', 'MWF 08:00-09:00', 'Spring 2025', to_date('01/15/2025', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('25S205', '1202', 'MW 14:00-15:30', 'Spring 2025', to_date('01/15/2025', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('25S206', '1301', 'TF 10:00-11:30', 'Spring 2025', to_date('01/15/2025', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('25S209', '1402', 'W 14:00-16:00', 'Spring 2025', to_date('01/15/2025', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('25S210', '1501', 'TR 08:00-09:30', 'Spring 2025', to_date('01/15/2025', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('25S211', '1502', 'MWF 11:00-12:00', 'Spring 2025', to_date('01/15/2025', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('25S213', '1601', 'MW 12:00-13:30', 'Spring 2025', to_date('01/15/2025', 'mm/dd/yyyy'), 35);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('25S116', '1604', 'TF 14:00-15:30', 'Spring 2025', to_date('01/15/2025', 'mm/dd/yyyy'), 35);

INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('25S302', '1002', 'MTr 09:00-10:30', 'Summer 2025', to_date('06/01/2025', 'mm/dd/yyyy'), 20);
INSERT INTO section (sectionID, coursenumber, schedule, semester, enrollmentDeadline, capacity) VALUES ('25S310', '1501', 'TF 11:00-12:30', 'Summer 2025', to_date('06/01/2025', 'mm/dd/yyyy'), 20);


INSERT INTO enroll VALUES ('LI123456', '23S101', 'A');  
INSERT INTO enroll VALUES ('LI123456', '23S107', 'B'); 
INSERT INTO enroll VALUES ('LI123456', '23S112', 'A'); 
INSERT INTO enroll VALUES ('LI123456', '24S204', 'A'); 
INSERT INTO enroll VALUES ('LI123456', '24S210', 'C'); 
INSERT INTO enroll VALUES ('LI123456', '24S211', 'B'); 
INSERT INTO enroll(studentID, sectionID) VALUES ('LI123456', '24S102'); 
INSERT INTO enroll(studentID, sectionID) VALUES ('LI123456', '24S106'); 
INSERT INTO enroll(studentID, sectionID) VALUES ('LI123456', '24S115'); 

INSERT INTO enroll VALUES ('SM123457', '24S210', 'A');  
INSERT INTO enroll VALUES ('SM123457', '24S203', 'B');  
INSERT INTO enroll VALUES ('SM123457', '24S202', 'B');  
INSERT INTO enroll(studentID, sectionID) VALUES ('SM123457', '24S102');  
INSERT INTO enroll(studentID, sectionID) VALUES ('SM123457', '24S107');  
INSERT INTO enroll(studentID, sectionID) VALUES ('SM123457', '24S104');  

INSERT INTO enroll(studentID, sectionID) VALUES ('WA123458', '24S103');  
INSERT INTO enroll(studentID, sectionID) VALUES ('WA123458', '24S102');  
INSERT INTO enroll(studentID, sectionID) VALUES ('WA123458', '24S104');  

INSERT INTO enroll VALUES ('LA123459', '24S202', 'A');  
INSERT INTO enroll VALUES ('LA123459', '24S203', 'B');  
INSERT INTO enroll VALUES ('LA123459', '24S204', 'B');  
INSERT INTO enroll(studentID, sectionID) VALUES ('LA123459', '24S102');  
INSERT INTO enroll(studentID, sectionID) VALUES ('LA123459', '24S105');  
INSERT INTO enroll(studentID, sectionID) VALUES ('LA123459', '24S104');  

commit;