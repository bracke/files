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
            Touch_Header (Model);
         end if;
         return;
      end if;
      if Natural (Names.Length) >= Max_Account_Names then
         Names.Clear;
      end if;
      Names.Insert (Id, To_Unbounded_String (Name));
      Touch_Header (Model);
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

end Files.Model.Status_Samples;
