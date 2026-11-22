with Files.Settings.Path_References;

--  What the window layer samples from the host for the status bar, the info
--  pane and the commands -- the current volume's free space, the names of
--  owner and group ids, and what the host offers (a trash, permissions,
--  ownership) -- so building a snapshot asks the OS nothing.
package Files.Model.Status_Samples is

   --  How long a volume-space sample stays current before the window layer
   --  samples again, so the readout follows a delete, a paste or another
   --  process rather than sticking until the user navigates away.
   Volume_Space_Refresh_Interval : constant Duration := 3.0;

   --  Record how the paths of the folder Path are matched against stored
   --  ones (Files.Settings.Path_References.Folding_In), asked once per
   --  folder. Moves no revision: a row matched before it was known asked its
   --  own volume, which is the folder's, and got the same answer.
   --
   --  @param Model Model to update.
   --  @param Path The folder it was asked for.
   --  @param Folds Whether that folder's paths are matched without regard to case.
   procedure Set_Name_Folding
     (Model : in out Window_Model;
      Path  : String;
      Folds : Boolean);

   --  @param Model Model to inspect.
   --  @return True when Set_Name_Folding answered for the current folder.
   function Name_Folding_Sampled (Model : Window_Model) return Boolean;

   --  @param Model Model to inspect.
   --  @return How the current folder's paths are matched: as sampled, or
   --    Ask_Each_Path when not (a view of no one folder, or before the
   --    window asked).
   function Name_Folding (Model : Window_Model) return Files.Settings.Path_References.Path_Folding;

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
      Space   : Files.File_System_Types.Volume_Space;
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
      return Files.File_System_Types.Volume_Space;

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
      Kind  : Files.File_System_Types.Account_Kind;
      Id    : Files.Types.Account_Id;
      Name  : String);

   --  @param Model Model to inspect.
   --  @param Kind Whether Id is a user id or a group id.
   --  @param Id Numeric user or group id.
   --  @return True when a name (possibly "") was recorded for Id.
   function Account_Name_Known
     (Model : Window_Model;
      Kind  : Files.File_System_Types.Account_Kind;
      Id    : Files.Types.Account_Id)
      return Boolean;

   --  @param Model Model to inspect.
   --  @param Kind Whether Id is a user id or a group id.
   --  @param Id Numeric user or group id.
   --  @return The recorded name, or "" when none was recorded.
   function Account_Name
     (Model : Window_Model;
      Kind  : Files.File_System_Types.Account_Kind;
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

   --  Record what the host offers: whether there is a trash folder to go
   --  to, and whether it can edit permissions and ownership. The window
   --  layer asks the host; Build_Snapshot and the command status read it.
   --  Bumps the revision only when one changed.
   --
   --  @param Model Model to update.
   --  @param Trash_Available Whether the host has a trash folder.
   --  @param Permissions_Supported Whether permission bits can be edited.
   --  @param Ownership_Supported Whether owner and group can be edited.
   --  @param Sampled When it was asked.
   procedure Set_Host
     (Model                 : in out Window_Model;
      Trash_Available       : Boolean;
      Permissions_Supported : Boolean;
      Ownership_Supported   : Boolean;
      Sampled               : Ada.Calendar.Time);

   --  @param Model Model to inspect.
   --  @return True once Set_Host recorded the host; until then the three
   --    answers below are not known.
   function Host_Sampled (Model : Window_Model) return Boolean;

   --  @param Model Model to inspect.
   --  @param Now The current time.
   --  @return True when the host was sampled less than
   --    Volume_Space_Refresh_Interval ago: a trash that appears (Windows
   --    makes the Recycle Bin's folder on the first delete) is seen soon.
   function Host_Is_Current
     (Model : Window_Model;
      Now   : Ada.Calendar.Time)
      return Boolean;

   --  @param Model Model to inspect.
   --  @return The sampled answer: the host has a trash folder.
   function Trash_Available (Model : Window_Model) return Boolean;

   --  @param Model Model to inspect.
   --  @return The sampled answer: permission bits can be edited.
   function Permissions_Supported (Model : Window_Model) return Boolean;

   --  @param Model Model to inspect.
   --  @return The sampled answer: owner and group can be edited.
   function Ownership_Supported (Model : Window_Model) return Boolean;

end Files.Model.Status_Samples;
