//------------------------------------------------------------------------------
// emHmiDemoMonitors.h
//
// Copyright (C) 2012,2014-2015,2022,2024 Oliver Hamann.
//
// Homepage: http://eaglemode.sourceforge.net/
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License version 3 as published by the
// Free Software Foundation.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License version 3 for
// more details.
//
// You should have received a copy of the GNU General Public License version 3
// along with this program. If not, see <http://www.gnu.org/licenses/>.
//------------------------------------------------------------------------------

#ifndef emHmiDemoMonitors_h
#define emHmiDemoMonitors_h

#ifndef emHmiDemoFile_h
#include <emHmiDemo/emHmiDemoFile.h>
#endif


class emHmiDemoMonitors : public emRasterLayout {
public:
	emHmiDemoMonitors(ParentArg parent, const emString & name, int caCount=3);
	virtual ~emHmiDemoMonitors();

private:
	emHmiDemoFile * * Ca;
};


#endif
