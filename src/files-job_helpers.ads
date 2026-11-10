--  Private command-line protocol shared by the application and test executable.
package Files.Job_Helpers is
   --  @return True after handling an internal worker command; False for normal startup.
   function Run_If_Requested return Boolean;
end Files.Job_Helpers;
