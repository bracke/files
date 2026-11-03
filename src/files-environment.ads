--  The process environment as files reads it: one answer for every unit,
--  asked of Hostkit, which owns how a host keeps its environment.
package Files.Environment is

   --  @param Name The variable.
   --  @return Its value, or "" when it is unset (or Name is empty).
   function Value (Name : String) return String;

   --  @param Name The variable.
   --  @return Whether it is set, even to nothing (a host where setting a
   --  variable to "" removes it never answers that).
   function Is_Set (Name : String) return Boolean;

   --  Set Name for this process and the programs it starts.
   --
   --  @param Name The variable.
   --  @param Value Its new value.
   procedure Set (Name : String; Value : String);

   --  Remove Name from this process's environment.
   --
   --  @param Name The variable.
   procedure Clear (Name : String);

end Files.Environment;
