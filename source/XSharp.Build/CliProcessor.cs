﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace XSharp.Build {
    public class CliProcessor {
        public class Arg {
            public string Value;
            public Switch Switch;
        }

        public class Switch {
            public string Name;
            public string Value;

            public string Check(string aDefault, string[] aAllowedValues, bool aCaseSensitive = false) {
                if (aAllowedValues.Contains(Value, aCaseSensitive ? null : StringComparer.OrdinalIgnoreCase)) {
                    return Value;
                }
                return aDefault;
            }
        }

        public bool RequireArgs = true;
        public bool PreserveSwitchCase = false;

        public List<Arg> Args = new List<Arg>();
        // Do not use dictionary. Dictionary loses order and dose not allow multiples.
        public List<Switch> Switches = new List<Switch>();

        protected bool mParsed = false;
        public void Parse(string[] aArgs) {
            if (RequireArgs && aArgs.Length == 0) {
                throw new Exception("No arguments were specified.");
            } else if (mParsed) {
                throw new Exception("Already parsed.");
            }
            mParsed = true;

            Switch xSwitch = null;
            foreach (var xArg in aArgs) {
                if (xArg.StartsWith("-")) {
                    xSwitch = new Switch();
                    var xParts = xArg.Substring(1).Split(':');
                    xSwitch.Name = PreserveSwitchCase ? xParts[0] : xParts[0].ToUpper();
                    if (xParts.Length > 1) {
                        xSwitch.Value = xParts[1];
                    }
                    Switches.Add(xSwitch);
                } else {
                    var xItem = new Arg() {Value = xArg, Switch = xSwitch};
                    Args.Add(xItem);
                }
            }
        }

        // Only returns first - by design
        public Switch GetSwitch(string aName, string aShortName = "") {
            if (PreserveSwitchCase == false) {
                aName = aName.ToUpper();
                aShortName = aShortName.ToUpper();
            }
            return Switches.FirstOrDefault(q => q.Name == aName || (aShortName != "" && q.Name == aShortName));
        }

        public Switch this[string aName, string aShortName = ""] {
            get { return GetSwitch(aName, aShortName); }
        }
        public List<Switch> GetSwitches(string aName, string aShortName = "") {
            if (PreserveSwitchCase == false) {
                aName = aName.ToUpper();
                aShortName = aShortName.ToUpper();
            }
            return Switches.FindAll(q => q.Name == aName || (aShortName != "" && q.Name == aShortName));
        }
    }
}
