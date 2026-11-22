with Files.Model.Support;

package body Files.Model.Recent is

   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   function In_Recent_View
     (Model : Window_Model)
      return Boolean is
     (Model.Recent_View_Active);

   procedure Note_Recent_Open
     (Model : in out Window_Model;
      Path  : String) is
   begin
      Touch_Header (Model);
      if Path /= "" then
         Model.Recent_Open_Queue.Append (To_Unbounded_String (Path));
      end if;
   end Note_Recent_Open;

   function Take_Recent_Opens
     (Model : in out Window_Model)
      return Files.Types.String_Vectors.Vector
   is
      Drained : constant Files.Types.String_Vectors.Vector := Model.Recent_Open_Queue;
   begin
      if not Drained.Is_Empty then
         Touch_Header (Model);
         Model.Recent_Open_Queue.Clear;
      end if;
      return Drained;
   end Take_Recent_Opens;

   procedure Note_Path_Move
     (Model : in out Window_Model;
      From  : String;
      To    : String)
     renames Files.Model.Support.Note_Path_Move;

   procedure Note_Path_Removed
     (Model : in out Window_Model;
      Path  : String) is
   begin
      if Path /= "" then
         Model.Path_Move_Queue.Append
           (Files.Types.Path_Move'
              (From => To_Unbounded_String (Path), To => Null_Unbounded_String, Kind => Files.Types.Removed));
      end if;
   end Note_Path_Removed;

   function Take_Path_Moves
     (Model : in out Window_Model)
      return Files.Types.Path_Move_Vectors.Vector is
   begin
      return Moves : constant Files.Types.Path_Move_Vectors.Vector := Model.Path_Move_Queue do
         Model.Path_Move_Queue.Clear;
      end return;
   end Take_Path_Moves;

end Files.Model.Recent;
