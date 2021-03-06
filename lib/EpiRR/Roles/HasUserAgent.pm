# Copyright 2013 European Molecular Biology Laboratory - European Bioinformatics Institute
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
package EpiRR::Roles::HasUserAgent;

use Moose::Role;

has 'user_agent' => (
    is       => 'rw',
    isa      => 'LWP::UserAgent',
    required => 1,
    lazy     => 1,
    default =>
      sub { LWP::UserAgent->new( agent => "EpiRR/1.00" ); }
);

1;