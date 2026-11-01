--  The process environment as files reads it: one answer for every unit,
--  asked of Hostkit, which owns how a host keeps its environment.
package Files.Environment is

   --  @param Name The variable.
   --  @return Its value, or "" when it is unset (or Name is empty).
   function Value (Name : String) return String;

end Files.Environment;
