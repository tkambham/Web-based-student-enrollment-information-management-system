drop table usersession cascade constraints;
drop table studentuser cascade constraints;
drop table adminuser cascade constraints;
drop table usertable;

CREATE TABLE usertable (
    username VARCHAR2(20) PRIMARY KEY,
    password VARCHAR2(12) NOT NULL,
    firstname VARCHAR2(20) NOT NULL,
    lastname VARCHAR2(20) NOT NULL,
    usertype VARCHAR2(12) NOT NULL
);


CREATE TABLE usersession (
    sessionid VARCHAR2(32) PRIMARY KEY,
    username VARCHAR2(20),
    sessiondate DATE,
    FOREIGN KEY (username) REFERENCES usertable(username)
);


CREATE TABLE studentuser (
    username VARCHAR2(20) PRIMARY KEY,
    admissiondate DATE NOT NULL,
    FOREIGN KEY (username) REFERENCES usertable(username) ON DELETE CASCADE
);


CREATE TABLE adminuser (
    username VARCHAR2(20) PRIMARY KEY,
    startdate DATE NOT NULL,
    FOREIGN KEY (username) REFERENCES usertable(username) ON DELETE CASCADE
);


INSERT INTO usertable VALUES ('Jhon23', '1234', 'Jhon', 'Doe', 'student');
INSERT INTO usertable VALUES ('Jane90', '2345', 'Jane', 'Deep', 'admin');
INSERT INTO usertable VALUES ('Mike96', '3456', 'Mike', 'Smith', 'studentadmin');


INSERT INTO studentuser VALUES ('Jhon23', to_date('12/01/2010', 'mm/dd/yyyy'));
INSERT INTO adminuser VALUES ('Jane90', to_date('10/31/2019', 'mm/dd/yyyy'));
INSERT INTO studentuser VALUES ('Mike96', to_date('11/25/2016', 'mm/dd/yyyy'));
INSERT INTO adminuser VALUES ('Mike96', to_date('5/30/2020', 'mm/dd/yyyy'));

COMMIT;
