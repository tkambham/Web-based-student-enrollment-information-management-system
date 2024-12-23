<?
include "verifysession.php";

$sessionid =$_GET["sessionid"];
verify_session($sessionid);

$semester = isset($_GET['semester']) ? $_GET['semester'] : '';
$course_number_input = isset($_GET['course_number']) ? $_GET['course_number'] : '';

$sql = "SELECT section.sectionID, 
                course.coursenumber,
                course.courseTitle,
                course.creditHours,
                section.semester,
                section.schedule,
                section.enrollmentDeadline,
                section.capacity,
                section.seatsAvailable ".
        "FROM section " .
        "JOIN course ON section.coursenumber = course.coursenumber ";

if($semester != ''){
    $sql .= " WHERE section.semester = '$semester'";
    if($course_number_input != ''){
      $sql .= " AND course.coursenumber LIKE '%$course_number_input%'";
    }
}
else{
    if($course_number_input != ''){
      $sql .= " WHERE course.coursenumber LIKE '%$course_number_input%'";
    }
    $sql .= "ORDER BY section.enrollmentDeadline DESC";
}


$result_array = execute_sql_in_oracle ($sql);
$result = $result_array["flag"];
$cursor = $result_array["cursor"];

if ($result == false){
  display_oracle_error_message($cursor);
  die("SQL Execution problem.");
}

$results_values = [];
while($value = oci_fetch_array ($cursor)){
    $results_values[] = $value;
}
oci_free_statement($cursor);

$sql2 = "SELECT studentID, username, usertype " .
       "FROM studentview " .
       "WHERE username = (SELECT username FROM usersession WHERE sessionid = '$sessionid')";

$result_array2 = execute_sql_in_oracle ($sql2);
$result2 = $result_array2["flag"];
$cursor2 = $result_array2["cursor"];

if ($result2 == false){
  display_oracle_error_message($cursor2);
  die("SQL Execution problem.");
}

if($values = oci_fetch_array ($cursor2)){
  oci_free_statement($cursor2);

  // saving the values in the variables
    $studentID = $values[0];
    $username = $values[1];
    $usertype = $values[2];
}


$sql3 = "SELECT DISTINCT enroll.sectionID, course.coursenumber, course.courseTitle, course.creditHours " .
       "FROM studentview " .
       "JOIN enroll ON studentview.studentID = enroll.studentID " .
       "JOIN section ON section.sectionID = enroll.sectionID " .
       "JOIN course ON section.coursenumber = course.coursenumber " .
       "WHERE studentview.username = (SELECT username FROM usersession WHERE sessionid = '$sessionid') AND section.semester = 'Spring 2025'";

$result_array3 = execute_sql_in_oracle($sql3);
$result3 = $result_array3["flag"];
$cursor3 = $result_array3["cursor"];

if ($result3 == false){
  display_oracle_error_message($cursor3);
  die("SQL Execution problem.");
}

$results_values2 = [];
while ($values = oci_fetch_array($cursor3)) {
    $results_values2[] = $values;
}
oci_free_statement($cursor3);

// Here we can generate the content of the welcome page
echo("Hello, $username <br /><br />");

if($usertype == 'student' || $usertype == 'studentadmin'){

  echo "<div style='display: flex; justify-content: space-between; align-items: flex-start;'>";

    // Left Div (Form)
    echo "<div style='width: 45%; padding: 30px; margin-left: 20px;'>";
      echo "<form method='get'>
              <input type='hidden' name='sessionid' value='$sessionid'>
              <label for='semester'>Select a semester:</label>
              <select id='semester' name='semester'>
                  <option value=''>All</option>
                  <option value='Fall 2024'>Fall 2024</option>
                  <option value='Spring 2025'>Spring 2025</option>
                  <option value='Summer 2025'>Summer 2025</option>
              </select>
              <br />
              <label for='course_number'>Enter the course number:</label>
              <input type='text' id='course_number' name='course_number'>
              <br>
              <input type='submit' value='Submit'>
              </form>  
              ";
    echo "</div>";

    // Right Div (Course List)
      echo "<div style='width: 45%; padding: 30px; margin-right: 20px;'>";
        echo "<h2 style='font-family: Arial, sans-serif; color: #333;'>Summary</h2>";
        echo "<table border='1' style='border-collapse: collapse; width: 100%;'>";
        echo "<tr>";
        echo "<th style = 'padding: 10px'>Section ID</th>";
        echo "<th style = 'padding: 10px'>Course Number</th>";
        echo "<th style = 'padding: 10px'>Course Title</th>";
        echo "<th style = 'padding: 10px'>Credit Hours</th>";
        echo "</tr>";
        if (count($results_values2) > 0) {
          foreach ($results_values2 as $values) {
              echo "<form method=\"post\" action=\"student_enrollment_drop_action.php?sessionid=$sessionid\">";
              echo "<input type=\"hidden\" name=\"username\" value=\"{$username}\">";
              echo "<input type=\"hidden\" name=\"studentid\" value=\"{$studentID}\">";
              echo "<input type=\"hidden\" name=\"sectionid\" value=\"{$values[0]}\">";
              echo "<input type=\"hidden\" name=\"coursetitle\" value=\"{$values[2]}\">";
              echo "<tr>";
              echo "<td>{$values[0]}</td>";
              echo "<td>{$values[1]}</td>";
              echo "<td>{$values[2]}</td>";
              echo "<td>{$values[3]}</td>";
              echo "<td><button type=\"submit\">Drop</button></td>";
              echo "</tr>";
              echo "</form>";
          }
        }
        echo "</table>";
      echo "</div>";

  echo "</div>";


    echo "<div style='width: 95%; padding: 30px; margin-right: 20px; margin-top:40px;'>";
        echo "<h2 style='font-family: Arial, sans-serif; color: #333;'>All Courses</h2>";
        echo "<table border='1' style='border-collapse: collapse; width: 100%;'>";
        echo "<tr>";
        echo "<th style = 'padding: 10px'>Section ID</th>";
        echo "<th style = 'padding: 10px'>Course Number</th>";
        echo "<th style = 'padding: 10px'>Course Title</th>";
        echo "<th style = 'padding: 10px'>Credit Hours</th>";
        echo "<th style = 'padding: 10px'>Semester</th>";
        echo "<th style = 'padding: 10px'>Schedule</th>";
        echo "<th style = 'padding: 10px'>Enroll Deadline</th>";
        echo "<th style = 'padding: 10px'>Capacity</th>";
        echo "<th style = 'padding: 10px'>Seats Available</th>";
        echo "<th style = 'padding: 10px'>PreReq Courses</th>";
        echo "<th style = 'padding: 10px'>Enroll</th>";
        echo "</tr>";

        $courseIds = [];

        foreach ($results_values as $values) {
            echo "<form method=\"post\" action=\"student_enrollment_add_action.php?sessionid=$sessionid\" id=\"enrollForm\">";
            echo "<tr>";
            echo "<input type=\"hidden\" name=\"username\" value=\"{$username}\">";
            echo "<input type=\"hidden\" name=\"studentid\" value=\"{$studentID}\">";
            echo "<input type=\"hidden\" name=\"sectionid\" value=\"{$values[0]}\">";
            echo "<input type=\"hidden\" name=\"coursenumber\" value=\"{$values[1]}\">";
            echo "<input type=\"hidden\" name=\"semester\" value=\"{$values[4]}\">";
            echo "<input type=\"hidden\" name=\"enrolldeadline\" value=\"{$values[6]}\">";
            echo "<input type=\"hidden\" name=\"seatsavailable\" value=\"{$values[8]}\">";
            echo "<td>{$values[0]}</td>";
            echo "<td>{$values[1]}</td>";
            echo "<td name=\"coursetitle\">{$values[2]}</td>";
            echo "<td name=\"credithours\">{$values[3]}</td>";
            echo "<td name=\"semester\">{$values[4]}</td>";
            echo "<td name=\"schedule\">{$values[5]}</td>";
            echo "<td>{$values[6]}</td>";
            echo "<td name=\"capacity\">{$values[7]}</td>";
            echo "<td>{$values[8]}</td>";
            $sqlP = "SELECT prerequisitecoursenumber FROM prerequisiteCourse WHERE coursenumber = '{$values[1]}'";

            $result_arrayP = execute_sql_in_oracle($sqlP);
            $resultP = $result_arrayP["flag"];
            $cursorP = $result_arrayP["cursor"];

            $prerequisiteCourses = [];
            while ($valuesP = oci_fetch_array($cursorP)) {
                $prerequisiteCourses[] = $valuesP;
            }
            oci_free_statement($cursorP);
            if (count($prerequisiteCourses) > 0) {
                echo "<td>";
                foreach ($prerequisiteCourses as $prereq) {
                    echo $prereq[0] . ", ";
                }
                echo "</td>";
            } else {
                echo "<td></td>";
            }
            echo "<td style='text-align: center;'><input type=\"checkbox\" name=\"selected_courses[]\" value=\"{$values[0]}\" class=\"courseCheckbox\" onclick=\"toggleEnrollButton()\"></td>";
            echo "</tr>";
        }
        echo "</table>";
        echo "<br>";
        echo "<button style=\"background-color: #4CAF50; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; float: right;\" type=\"submit\" id=\"enrollButton\" disabled>Enroll</button>";
        echo "</form>";
    echo "</div>";

    echo '<form method="post" action="student.php?sessionid=' . $sessionid . '" style="text-align: center;">
            <input type="submit" value="Go Back" style="background-color: #4CAF50; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; font-size: 16px;">
          </form>';
    echo "<br />";

    echo "<script>
            function toggleEnrollButton() {
                var checkboxes = document.getElementsByClassName('courseCheckbox');
                var enrollButton = document.getElementById('enrollButton');
                var checked = false;
                for (var i = 0; i < checkboxes.length; i++) {
                    if (checkboxes[i].checked) {
                        checked = true;
                        break;
                    }
                }
                enrollButton.disabled = !checked;
            }
          </script>";

    echo "<script>
            document.getElementById('enrollForm').addEventListener('submit', function(event) {
              const selectedCourses = [];
              const checkboxes = document.querySelectorAll('.courseCheckbox:checked');
              checkboxes.forEach(checkbox => selectedCourses.push(checkbox.value));

              if (selectedCourses.length === 0) {
                event.preventDefault();
                alert('Please select at least one course to enroll.');
              }

              if (selectedCourses.length > 0) {
              selectedCourses.forEach(courseId => {
                  let input = document.createElement('input');
                  input.type = 'hidden';
                  input.name = 'selected_courses[]';
                  input.value = '{$courseIds}';
                  document.getElementById('enrollForm').appendChild(input);
              });
              let input2 = document.createElement('input');
              input2.type = 'hidden';
              input2.name = 'studentID';
              input2.value = '{$studentID}';
              document.getElementById('enrollForm').appendChild(input2);

              let input3 = document.createElement('input');
              input3.type = 'hidden';
              input3.name = 'username';
              input3.value = '{$username}';
              document.getElementById('enrollForm').appendChild(input3);
              }
            }
          </script>";
    }
    else{
      echo "You are not authorized to view this page.";
    }
?>