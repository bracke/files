with Files.Model.Support;

package body Files.Model.Status_Samples is

   use Files.Model.Support;
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Files.File_System_Types.Volume_Space;

   procedure Set_Volume_Space
     (Model   : in out Window_Model;
      Path    : String;
      Space   : Files.File_System_Types.Volume_Space;
      Sampled : Ada.Calendar.Time) is
   begin
      --  The bar and the free-space text are header: no row changes.
      if Model.Volume_Sample.Space /= Space or else To_String (Model.Volume_Sample.Path) /= Path then
         Touch_Header (Model);
      end if;
      Model.Volume_Sample := (Space => Space, Path => To_Unbounded_String (Path), Sampled => Sampled);
   end Set_Volume_Space;

   procedure Set_Name_Folding
     (Model : in out Window_Model;
      Path  : String;
      Folds : Boolean) is
   begin
      Model.Name_Folding := (Path => To_Unbounded_String (Path), Folds => Folds);
   end Set_Name_Folding;

   function Name_Folding_Sampled (Model : Window_Model) return Boolean is
     (Length (Model.Name_Folding.Path) > 0 and then To_String (Model.Name_Folding.Path) = Current_Path (Model));

   function Name_Folding (Model : Window_Model) return Files.Settings.Path_References.Path_Folding is
     (if not Name_Folding_Sampled (Model) then Files.Settings.Path_References.Ask_Each_Path
      elsif Model.Name_Folding.Folds then Files.Settings.Path_References.Match_Folded
      else Files.Settings.Path_References.Match_Exactly);

   function Volume_Space_Is_Current
     (Model : Window_Model;
      Now   : Ada.Calendar.Time)
      return Boolean is
   begin
      return Length (Model.Volume_Sample.Path) > 0
        and then To_String (Model.Volume_Sample.Path) = Current_Path (Model)
        --  A clock set back since the sample is no reason to keep it.
        and then Now >= Model.Volume_Sample.Sampled
        and then Now <= Model.Volume_Sample.Sampled + Volume_Space_Refresh_Interval;
   end Volume_Space_Is_Current;

   function Volume_Space_Of
     (Model : Window_Model)
      return Files.File_System_Types.Volume_Space is
     (if To_String (Model.Volume_Sample.Path) = Current_Path (Model) then Model.Volume_Sample.Space
      else (others => <>));

   procedure Set_Account_Name
     (Model : in out Window_Model;
      Kind  : Files.File_System_Types.Account_Kind;
      Id    : Files.Types.Account_Id;
      Name  : String)
   is
      --  Ids on one host are few, but bound the table so a long session over
      --  many foreign volumes cannot grow it without limit.
      Max_Account_Names : constant := 4096;
      Names : Account_Name_Maps.Map renames Model.Account_Names.Names (Kind);
      Found : constant Account_Name_Maps.Cursor := Names.Find (Id);
   begin
      if Account_Name_Maps.Has_Element (Found) then
         if To_String (Account_Name_Maps.Element (Found)) /= Name then
            Names.Replace_Element (Found, To_Unbounded_String (Name));
            Touch_Info (Model);
         end if;
         return;
      end if;
      if Natural (Names.Length) >= Max_Account_Names then
         Names.Clear;
      end if;
      Names.Insert (Id, To_Unbounded_String (Name));
      Touch_Info (Model);
   end Set_Account_Name;

   function Account_Name_Known
     (Model : Window_Model;
      Kind  : Files.File_System_Types.Account_Kind;
      Id    : Files.Types.Account_Id)
      return Boolean is
     (Model.Account_Names.Names (Kind).Contains (Id));

   function Account_Name
     (Model : Window_Model;
      Kind  : Files.File_System_Types.Account_Kind;
      Id    : Files.Types.Account_Id)
      return String
   is
      Found : constant Account_Name_Maps.Cursor := Model.Account_Names.Names (Kind).Find (Id);
   begin
      if Account_Name_Maps.Has_Element (Found) then
         return To_String (Account_Name_Maps.Element (Found));
      end if;
      return "";
   end Account_Name;

   procedure Note_Account_Names_Sampled
     (Model : in out Window_Model) is
   begin
      Model.Account_Names.Sampled := Model.Revision_Value;
   end Note_Account_Names_Sampled;

   function Account_Names_Current
     (Model : Window_Model)
      return Boolean is
     (Model.Account_Names.Sampled = Model.Revision_Value);

   procedure Set_Host
     (Model                 : in out Window_Model;
      Trash_Available       : Boolean;
      Permissions_Supported : Boolean;
      Ownership_Supported   : Boolean;
      Sampled               : Ada.Calendar.Time)
   is
      Sample : constant Host_Sample_State :=
        (Sampled               => True,
         Trash_Available       => Trash_Available,
         Permissions_Supported => Permissions_Supported,
         Ownership_Supported   => Ownership_Supported,
         Sampled_At            => Sampled);
   begin
      --  The commands and the info pane's editors are header: no row changes;
      --  the info pane's rows are rebuilt (Info_Revision).
      if not Model.Host_Sample.Sampled
        or else Model.Host_Sample.Trash_Available /= Trash_Available
        or else Model.Host_Sample.Permissions_Supported /= Permissions_Supported
        or else Model.Host_Sample.Ownership_Supported /= Ownership_Supported
      then
         Touch_Info (Model);
      end if;
      Model.Host_Sample := Sample;
   end Set_Host;

   function Host_Sampled (Model : Window_Model) return Boolean is (Model.Host_Sample.Sampled);

   function Host_Is_Current
     (Model : Window_Model;
      Now   : Ada.Calendar.Time)
      return Boolean is
     (Model.Host_Sample.Sampled
      --  A clock set back since the sample is no reason to keep it.
      and then Now >= Model.Host_Sample.Sampled_At
      and then Now <= Model.Host_Sample.Sampled_At + Volume_Space_Refresh_Interval);

   function Trash_Available (Model : Window_Model) return Boolean is (Model.Host_Sample.Trash_Available);

   function Permissions_Supported (Model : Window_Model) return Boolean is
     (Model.Host_Sample.Permissions_Supported);

   function Ownership_Supported (Model : Window_Model) return Boolean is (Model.Host_Sample.Ownership_Supported);

end Files.Model.Status_Samples;
