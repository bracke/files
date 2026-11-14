--  What the window layer samples from the host for the status bar and the
--  info pane -- the current volume's free space and the names of owner and
--  group ids -- so building a snapshot asks the OS nothing.
package Files.Model.Status_Samples is

   --  How long a volume-space sample stays current before the window layer
   --  samples again, so the readout follows a delete, a paste or another
   --  process rather than sticking until the user navigates away.
   Volume_Space_Refresh_Interval : constant Duration := 3.0;

   --  Record a volume-space sample. The window layer takes it (a statvfs);
   --  Build_Snapshot only reads it, so building a snapshot touches no disk.
   --  Bumps the revision only when what would be shown changed.
   --
   --  @param Model Model to update.
   --  @param Path Directory the sample was taken for.
   --  @param Space The sampled free and total bytes.
   --  @param Sampled When it was taken.
   procedure Set_Volume_Space
     (Model   : in out Window_Model;
      Path    : String;
      Space   : Volume_Space;
      Sampled : Ada.Calendar.Time);

   --  @param Model Model to inspect.
   --  @param Now The current time.
   --  @return True when the sample is for the current directory and younger
   --    than Volume_Space_Refresh_Interval.
   function Volume_Space_Is_Current
     (Model : Window_Model;
      Now   : Ada.Calendar.Time)
      return Boolean;

   --  @param Model Model to inspect.
   --  @return The last sample, or an unknown space when it was taken for
   --    another directory.
   function Volume_Space_Of
     (Model : Window_Model)
      return Volume_Space;

   --  Record the name of a user or group id. The window layer resolves it (an
   --  NSS lookup); Build_Snapshot only reads it, so building a snapshot asks
   --  the OS nothing. Bumps the revision only when the recorded name changed.
   --
   --  @param Model Model to update.
   --  @param Kind Whether Id is a user id or a group id.
   --  @param Id Numeric user or group id.
   --  @param Name Resolved name, or "" when the id has none.
   procedure Set_Account_Name
     (Model : in out Window_Model;
      Kind  : Account_Kind;
      Id    : Files.Types.Account_Id;
      Name  : String);

   --  @param Model Model to inspect.
   --  @param Kind Whether Id is a user id or a group id.
   --  @param Id Numeric user or group id.
   --  @return True when a name (possibly "") was recorded for Id.
   function Account_Name_Known
     (Model : Window_Model;
      Kind  : Account_Kind;
      Id    : Files.Types.Account_Id)
      return Boolean;

   --  @param Model Model to inspect.
   --  @param Kind Whether Id is a user id or a group id.
   --  @param Id Numeric user or group id.
   --  @return The recorded name, or "" when none was recorded.
   function Account_Name
     (Model : Window_Model;
      Kind  : Account_Kind;
      Id    : Files.Types.Account_Id)
      return String;

   --  Note that the account names the info pane needs were sampled at the
   --  current revision, so the window layer can skip sampling until the model
   --  changes again. Does not bump the revision.
   --
   --  @param Model Model to update.
   procedure Note_Account_Names_Sampled
     (Model : in out Window_Model);

   --  @param Model Model to inspect.
   --  @return True when Note_Account_Names_Sampled ran at the current revision.
   function Account_Names_Current
     (Model : Window_Model)
      return Boolean;

end Files.Model.Status_Samples;
