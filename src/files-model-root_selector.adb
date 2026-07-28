with Files.Model.Support;

package body Files.Model.Root_Selector is
   use Files.Model.Support;
   use Ada.Strings.Unbounded;
   use type Guikit.Input.Navigation_Direction;

   procedure Open_Root_Selector
     (Model : in out Window_Model;
      Roots : Files.Types.String_Vectors.Vector)
   is
      Entries : Files.File_System.Root_Entry_Vectors.Vector;
   begin
      for Root of Roots loop
         Entries.Append
           (Files.File_System.Root_Entry'
              (Path  => Root,
               Label => Root,
               Kind  => Files.File_System.Root_Filesystem,
               Volume_Name => Root,
               Ready => Files.File_System.Root_Ready,
               Removable => False));
      end loop;

      Open_Root_Selector (Model, Entries);
   end Open_Root_Selector;

   procedure Open_Root_Selector
     (Model : in out Window_Model;
      Roots : Files.File_System.Root_Entry_Vectors.Vector) is
   begin
      Model.Root_Entries := Roots;
      Model.Root_Selector_Open := not Roots.Is_Empty;
      Model.Root_Selected := (if Model.Root_Selector_Open then 1 else 0);
      Model.Settings_Pane_Open := False;
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Model.Focus_Value := Files.Types.Focus_None;
   end Open_Root_Selector;

   procedure Close_Root_Selector
     (Model : in out Window_Model) is
   begin
      Clear_Root_Selector_State (Model);
   end Close_Root_Selector;

   function Root_Selector_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Root_Selector_Open;
   end Root_Selector_Is_Open;

   function Root_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Root_Entries.Length);
   end Root_Count;

   function Root_Selected_Index
     (Model : Window_Model)
      return Natural is
   begin
      if not Model.Root_Selector_Open
        or else Model.Root_Selected = 0
        or else Model.Root_Selected > Root_Count (Model)
      then
         return 0;
      end if;

      return Model.Root_Selected;
   end Root_Selected_Index;

   procedure Set_Root_Selected_Index
     (Model : in out Window_Model;
      Index : Natural) is
   begin
      if not Model.Root_Selector_Open or else Root_Count (Model) = 0 then
         Model.Root_Selected := 0;
      elsif Index = 0 then
         Model.Root_Selected := 0;
      else
         Model.Root_Selected := Natural'Min (Index, Root_Count (Model));
      end if;
   end Set_Root_Selected_Index;

   procedure Move_Root_Selection
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
   is
      Count   : constant Natural := Root_Count (Model);
      Current : constant Natural := Root_Selected_Index (Model);
   begin
      if not Model.Root_Selector_Open or else Count = 0 then
         Model.Root_Selected := 0;
      elsif Current = 0 then
         Model.Root_Selected := 1;
      elsif Direction = Guikit.Input.Move_Up or else Direction = Guikit.Input.Move_Left then
         Model.Root_Selected := (if Current = 1 then Count else Current - 1);
      else
         Model.Root_Selected := (if Current = Count then 1 else Current + 1);
      end if;
   end Move_Root_Selection;

   function Root_Path
     (Model : Window_Model;
      Index : Positive)
      return String is
   begin
      if Model.Root_Entries.Is_Empty or else Index > Model.Root_Entries.Last_Index then
         return "";
      end if;

      return To_String (Model.Root_Entries.Element (Index).Path);
   end Root_Path;

   function Root_Label
     (Model : Window_Model;
      Index : Positive)
      return String is
   begin
      if Model.Root_Entries.Is_Empty or else Index > Model.Root_Entries.Last_Index then
         return "";
      end if;

      return To_String (Model.Root_Entries.Element (Index).Label);
   end Root_Label;

   function Root_Kind
     (Model : Window_Model;
      Index : Positive)
      return Files.File_System.Root_Kind is
   begin
      if Model.Root_Entries.Is_Empty or else Index > Model.Root_Entries.Last_Index then
         return Files.File_System.Root_Filesystem;
      end if;

      return Model.Root_Entries.Element (Index).Kind;
   end Root_Kind;

   function Root_Is_Removable
     (Model : Window_Model;
      Index : Positive)
      return Boolean is
   begin
      if Model.Root_Entries.Is_Empty or else Index > Model.Root_Entries.Last_Index then
         return False;
      end if;

      return Model.Root_Entries.Element (Index).Removable;
   end Root_Is_Removable;

end Files.Model.Root_Selector;
