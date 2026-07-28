with Files.Model;
with Files.Settings;

--  Internal helpers shared across the Files.Operations group children (built as
--  Files.Operations splits its former monolith into cohesive child packages).
--  A private child so only the Files.Operations hierarchy can see it; the public
--  Operation_Result/Operation_Status types come from the parent spec.
private package Files.Operations.Support is

   --  The empty open action (no executable, no arguments), used as the default
   --  Action for results that do not launch anything.
   --
   --  @return An open action with an empty executable and no arguments.
   function Empty_Action return Files.Settings.Open_Action;

   --  Ada.Directories.Exists raises Name_Error on a malformed path rather than
   --  returning False; this treats any failure as "does not exist" so it cannot
   --  escape an operation as an unhandled exception.
   --
   --  @param Path Filesystem path to test.
   --  @return True when Path exists, False when it does not or the test failed.
   function Exists_Safely (Path : String) return Boolean;

   --  Construct an Operation_Result, folding an open action's fields into the
   --  flat result record.
   --
   --  @param Status Operation status to report.
   --  @param Error_Key Localisation key for an error, or "" when none.
   --  @param Path Path the result refers to, or "" when none.
   --  @param Action Open action whose fields are folded into the result.
   --  @param Attempted Whether a launch was attempted.
   --  @param Found Whether the executable was found.
   --  @param Exit_Known Whether an exit status is known.
   --  @param Exit_Status The child exit status when known.
   --  @return The assembled operation result.
   function Make_Result
     (Status      : Operation_Status;
      Error_Key   : String := "";
      Path        : String := "";
      Action      : Files.Settings.Open_Action := Empty_Action;
      Attempted   : Boolean := False;
      Found       : Boolean := False;
      Exit_Known  : Boolean := False;
      Exit_Status : Integer := 0)
      return Operation_Result;

   --  Set the model error and return a disabled result for a command that is not
   --  currently applicable.
   --
   --  @param Model Window model whose error state is set.
   --  @param Error_Key Localisation key for the disabled reason.
   --  @return A disabled operation result carrying Error_Key.
   function Disabled
     (Model     : in out Files.Model.Window_Model;
      Error_Key : String)
      return Operation_Result;

   --  Environment variable value, or "" when absent or on any failure.
   --
   --  @param Name Environment variable name.
   --  @return The variable's value, or "" when unset or unreadable.
   function Safe_Environment_Value (Name : String) return String;

   --  Whether Executable names something this host will actually run: an
   --  on-PATH command, or a path that is a regular executable file.
   --
   --  @param Executable Executable name to look up, or a path to a file.
   --  @return True when it resolves to a runnable executable.
   function Executable_Is_Available (Executable : String) return Boolean;

   --  Reload the model's current directory (optionally re-selecting Select_Name),
   --  refreshing the item list and directory signature.
   --
   --  @param Model Window model whose current directory is reloaded.
   --  @param Settings Settings model used to classify the reload.
   --  @param Select_Name Item name to re-select after reload, or "" for none.
   --  @return Success result, or a failed result when the reload fails.
   function Reload_Current_Directory
     (Model       : in out Files.Model.Window_Model;
      Settings    : Files.Settings.Settings_Model;
      Select_Name : String := "")
      return Operation_Result;

end Files.Operations.Support;
