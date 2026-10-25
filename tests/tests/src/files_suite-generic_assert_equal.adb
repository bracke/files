with AUnit.Assertions;

procedure Files_Suite.Generic_Assert_Equal (Actual, Expected : Value; Message : String) is
begin
   AUnit.Assertions.Assert
     (Actual = Expected, Message & " (expected " & Expected'Image & ", got " & Actual'Image & ")");
end Files_Suite.Generic_Assert_Equal;
