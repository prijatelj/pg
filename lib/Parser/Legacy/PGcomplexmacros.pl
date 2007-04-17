# This file     is PGcomplexmacros.pl
# This includes the subroutines for the ANS macros, that
# is, macros allowing a more flexible answer checking
####################################################################
# Copyright @ 1995-2002 The WeBWorK Team
# All Rights Reserved
####################################################################
#$Id$


=head1 NAME

	Macros for complex numbers for the PG language

=head1 SYNPOSIS



=head1 DESCRIPTION

=cut


BEGIN{
	be_strict();
	
}



sub _PGcomplexmacros_init {
}
# export functions from Complex1.

foreach my $f (@Complex1::EXPORT) {
#		#PG_restricted_eval("\*$f = \*Complex1::$f"); # this is too clever -- 
		                                              # the original subroutines are destroyed
#        	next if $f eq 'sqrt';  #exporting the square root caused conflicts with the standard version
#               	               		# You can still use Complex1::sqrt to take square root of complex numbers
#        	next if $f eq 'log';  #exporting loq caused conflicts with the standard version
#                               # You can still use Complex1::log to take square root of complex numbers

	next if $f eq 'i' || $f eq 'pi';
	my $code = PG_restricted_eval("\\&CommonFunction::$f");
	if (defined($code) && defined(&{$code})) {
		$CommonFunction::function{$f} = "Complex1::$f";  # PGcommonMacros now takes care of this.
	} else {
		my $string = qq{sub main::$f {&Complex1::$f}};
		PG_restricted_eval($string);
	}

}


# You need to add 
# sub i();  # to your problem or else to dangerousMacros.pl
# in order to use expressions such as 1 +3*i;
# Without this prototype you would have to write 1+3*i();
# The prototype has to be defined at compile time, but dangerousMacros.pl is complied first.
#Complex1::display_format('cartesian');

# number format used frequently in strict prefilters
my $number = '([+-]?)(?=\d|\.\d)\d*(\.\d*)?(E([+-]?\d+))?';




=head4 cplx_cmp
	
	This subroutine compares complex numbers.
	Available prefilters include:
	each of these are called by cplx_cmp( answer, mode => '(prefilter name)' )
	'std'			The standard comparison method for complex numbers. This option it the default
				and works with any combination of cartesian numbers, polar numbers, and
				functions. The default display method is cartesian, for all methods, but if
				the student answer is polar, even in part, then their answer will be displayed
				that way.
	'strict_polar'		This is still under developement. The idea is to check to make sure that there
				only a single term in front of the e and after it... but the method does not
				check to make sure that the i is in the exponent, nor does it handle cases
				where the polar has e** coefficients.
	'strict_num_cartesian'	This prefilter allows only complex numbers of the form "a+bi" where a and b
				are strictly numbers.
	'strict_num_polar'	This prefilter allows only complex numbers of the form "ae^(bi)" where a and b
				are strictly numbers.
	'strict'		This is a combination of strict_num_cartesian and strict_num_polar, so it
				allows complex numbers of either the form "a+bi" or "ae^(bi)" where a and b
				are strictly numbers.


=cut

my %cplx_context = (
	'std' => 'Complex',
	'strict' => 'LimitedComplex-strict',
	'strict_polar' => 'LimitedComplex-polar',
	'strict_cartesian' => 'LimitedComplex-cartesian',
	'strict_num_polar' => 'LimitedComplex-polar-strict',
	'strict_num_cartesian' => 'LimitedComplex-cartesian-strict',
);

sub cplx_cmp {
	return original_cplx_cmp(@_) if $main::useOldAnswerMacros;

	my $correctAnswer = shift;
	my %cplx_params = @_;

	#
	#  Get default options
	#
	assign_option_aliases( \%cplx_params,
		'reltol'        =>  'relTol',
	);
	set_default_options(\%cplx_params,
		'tolType'		=>  (defined($cplx_params{tol}) ) ? 'absolute' : 'relative',
			# default mode should be relative, to obtain this tol must not be defined
		'tolerance'		=>	$main::numAbsTolDefault, 
		'relTol'		=>	$main::numRelPercentTolDefault,
		'zeroLevel'		=>	$main::numZeroLevelDefault,
		'zeroLevelTol'		=>	$main::numZeroLevelTolDefault,
		'format'		=>	$main::numFormatDefault,
		'debug'			=> 	0,
		'mode' 			=> 	'std',
		'strings'		=> 	undef,
	);
	my $format			=	$cplx_params{'format'};
	my $mode			=	$cplx_params{'mode'};
	
	if( $cplx_params{tolType} eq 'relative' ) {
		$cplx_params{'tolerance'} = .01*$cplx_params{'relTol'};
	}

	my $context = $cplx_context{$mode};
	unless ($context) {$context = "Complex"; warn "Unknown mode '$mode'"}
	$context = Parser::Context->getCopy(\%main::context,$context);

	#
	#  Set the format for the context
	#
	$context->{format}{number} = $cplx_params{'format'} if $cplx_params{'format'};
	
	#
	#  Add the strings to the context
	#
	if ($cplx_params{strings}) {
	  foreach my $string (@{$cplx_params{strings}}) {
	    my %tex = ($string =~ m/(-?)inf(inity)?/i)? (TeX => "$1\\infty"): ();
	    $context->strings->add(uc($string) => {%tex})
	      unless $context->strings->get(uc($string));
	  }
	}

	#
	#  Set the tolerances
	#
	if ($cplx_params{tolType} eq 'absolute') {
	  $context->flags->set(
	    tolerance => $cplx_params{tolerance},
	    tolType => 'absolute',
	  );
	} else {
	  $context->flags->set(
	    tolerance => .01*$cplx_params{tolerance},
	    tolType => 'relative',
	  );
	}
	$context->flags->set(
	  zeroLevel => $cplx_params{zeroLevel},
	  zeroLevelTol => $cplx_params{zeroLevelTol},
	);

	#
	#  Get the proper Parser object for the professor's answer
	#  using the initialized context
	#
	my $oldContext = Parser::Context->current(\%main::context,$context); my $z;
	if (ref($correctAnswer) =~ /^Complex1?$/) {
	  $z = Value::Complex->new($correctAnswer->Re,$correctAnswer->Im);
	} else {
	  $z = Value::Formula->new($correctAnswer);
	  die "The professor's answer can't be a formula" unless $z->isConstant;
	  $z = $z->eval; $z = new Value::Complex($z) unless Value::class($z) eq 'String';
	}
	$z->{correct_ans} = $correctAnswer;

	#
	#  Get the answer checker from the parser object
	#
	my $cmp = $z->cmp;
	$cmp->install_pre_filter(sub {
	  my $rh_ans = shift;
	  $rh_ans->{original_student_ans} = $rh_ans->{student_ans};
	  $rh_ans->{original_correct_ans} = $rh_ans->{correct_ans};
	  return $rh_ans;
	});
	$cmp->install_post_filter(sub {
	  my $rh_ans = shift; my $z = $rh_ans->{student_value};
	  #
	  #  Stringify student answer (use polar form if student did)
	  #
	  if (ref($z) && $z->isNumber) {
	    $z = Value::Complex->new($z); # promote real to complex
	    if ($rh_ans->{original_student_ans} =~ m/(^|[^a-zA-Z])e\s*(\^|\*\*)/) {
	      my ($a,$b) = ($z->mod,$z->arg);
	      unless ($context->flag('strict_numeric')) {
		my $rt = (new Complex($z->Re->value,$z->Im->value))->stringify_polar;
		($a,$b) = ($rt =~ m/\[(.*),(.*)\]/);
	      }
	      $a = Value::Real->new($a)->string;
	      $b = Value::Real->new($b)->string if Value::matchNumber($b);
	      if ($b eq '0') {
		$rh_ans->{student_ans} = $a;
	      } else {
		if ($a eq '1') {$a = ''} elsif ($a eq '-1') {$a = '-'} else {$a .= '*'}
		if ($b eq '1') {$b = 'i'} elsif ($b eq '-1') {$b = '(-i)'} else {$b = "($b i)"}
		$rh_ans->{student_ans} = $a.'e^'.$b;
	      }
	    } else {
	      $rh_ans->{student_ans} = $rh_ans->{student_value}->string;
	    }
	  }
	  return $rh_ans;
	});
	$cmp->{debug} = $cplx_params{debug};
	Parser::Context->current(\%main::context,$oldContext);

	return $cmp;
}

#
#  The original version, for backward compatibility
#  (can be removed when the Parser-based version is more fully tested.)
#
sub original_cplx_cmp {
	my $correctAnswer = shift;
	my %cplx_params = @_;
	
	assign_option_aliases( \%cplx_params,
		'reltol'        =>  'relTol',
	);
	set_default_options(\%cplx_params,
		'tolType'		=>  (defined($cplx_params{tol}) ) ? 'absolute' : 'relative',
			# default mode should be relative, to obtain this tol must not be defined
		'tolerance'		=>	$main::numAbsTolDefault, 
		'relTol'		=>	$main::numRelPercentTolDefault,
		'zeroLevel'		=>	$main::numZeroLevelDefault,
		'zeroLevelTol'		=>	$main::numZeroLevelTolDefault,
		'format'		=>	$main::numFormatDefault,
		'debug'			=> 	0,
		'mode' 			=> 	'std',
		'strings'		=> 	undef,
	);
	my $format			=	$cplx_params{'format'};
	my $mode			=	$cplx_params{'mode'};
	
	if( $cplx_params{tolType} eq 'relative' ) {
		$cplx_params{'tolerance'} = .01*$cplx_params{'relTol'};
	}
	
	my $formattedCorrectAnswer;
	my $correct_num_answer;
	my $corrAnswerIsString = 0;
	

	if (defined($cplx_params{strings}) && $cplx_params{strings}) {
		my $legalString	= '';
		my @legalStrings = @{$cplx_params{strings}};
		$correct_num_answer = $correctAnswer;
		$formattedCorrectAnswer = $correctAnswer;
		foreach	$legalString (@legalStrings) {
			if ( uc($correctAnswer) eq uc($legalString) ) {
				$corrAnswerIsString	= 1;
				
				last;
			}
		}		  ## at	this point $corrAnswerIsString = 0 iff correct answer is numeric
	} else {
		$correct_num_answer = $correctAnswer;
		$formattedCorrectAnswer = prfmt( $correctAnswer, $cplx_params{'format'} );
	}
	$correct_num_answer = math_constants($correct_num_answer);
	
	my $PGanswerMessage = '';

#
#  The following lines don't have any effect (other than to take time and produce errors
#  in the error log).  The $correctVal is replaced on the line following the comments,
#  and the error values are never used.  It LOOKS like this was supposed to perform a
#  check on the professor's answer, but that is not occurring.  (There used to be some
#  error checking, but that was removed in version 1.9 and it had been commented out
#  prior to that because it was always producing errors.  This is because $correct_num_answer
#  usually is somethine like "1+4i", which will produce a "missing operation before 'i'"
#  error, and "1-i" wil produce an "amiguous use of '-i' resolved as '-&i'" message.
#  You probably need a call to check_syntax and the other filters that are used on
#  the student answer first. (Unless the item is already a reference to a Complex,
#  in which canse you should just accept it.)
#
#	my ($inVal,$correctVal,$PG_eval_errors,$PG_full_error_report);
	my $correctVal;
#	if (defined($correct_num_answer) && $correct_num_answer =~ /\S/ && $corrAnswerIsString == 0 )	{
#			($correctVal, $PG_eval_errors,$PG_full_error_report) = PG_answer_eval($correct_num_answer);
#	} else { # case of a string answer
#		$PG_eval_errors	= '	';
#		$correctVal = $correctAnswer;
#	}
	
	########################################################################
	$correctVal = $correct_num_answer;
	$correctVal = cplx( $correctVal, 0 ) unless ref($correctVal) =~/^Complex?/ || $corrAnswerIsString == 1;
	
	#construct the answer evaluator 
    	my $answer_evaluator             = new AnswerEvaluator; 
		$answer_evaluator->{debug}       = $cplx_params{debug};
    	$answer_evaluator->ans_hash( 	 
    						correct_ans 			=> 	$correctVal,
    					 	type					=>	"cplx_cmp",
    					 	tolerance				=>	$cplx_params{tolerance},
					 		tolType					=> 	'absolute', #	$cplx_params{tolType},
					 		original_correct_ans	=>	$formattedCorrectAnswer,
     					 	answerIsString			=>	$corrAnswerIsString,
							answer_form				=>	'cartesian',
     	);
    	my ($in, $formattedSubmittedAnswer);
	$answer_evaluator->install_pre_filter(sub {my $rh_ans = shift; 
		$rh_ans->{original_student_ans} = $rh_ans->{student_ans}; $rh_ans;}
	);
	if (defined($cplx_params{strings}) && $cplx_params{strings}) {
			$answer_evaluator->install_pre_filter(\&check_strings, %cplx_params);
	}

	$answer_evaluator->install_pre_filter(\&check_syntax);
	$answer_evaluator->install_pre_filter(\&math_constants);
	$answer_evaluator->install_pre_filter(\&cplx_constants);
	$answer_evaluator->install_pre_filter(\&check_for_polar);
	if ($mode eq 'std')	{
				# do nothing	
	} elsif ($mode eq 'strict_polar') {
		$answer_evaluator->install_pre_filter(\&is_a_polar);
	} elsif ($mode eq 'strict_num_cartesian') {
		$answer_evaluator->install_pre_filter(\&is_a_numeric_cartesian);
	} elsif ($mode eq 'strict_num_polar') {
		$answer_evaluator->install_pre_filter(\&is_a_numeric_polar);
	} elsif ($mode eq 'strict') {
		$answer_evaluator->install_pre_filter(\&is_a_numeric_complex);
	} else {	
		$PGanswerMessage = 'Tell your professor	that there is an error in his or her answer mechanism. No mode was specified.';
		$formattedSubmittedAnswer =	$in;
	}

	if ($corrAnswerIsString == 0 ){		# avoiding running compare_cplx when correct answer is a string.
		$answer_evaluator->install_evaluator(\&compare_cplx, %cplx_params);
	}
	  
	 	
###############################################################################
# We'll leave these next lines out for now, so that the evaluated versions of the student's and professor's
# can be displayed in the answer message.  This may still cause a few anomolies when strings are used
#
###############################################################################

	$answer_evaluator->install_post_filter(\&fix_answers_for_display);
	$answer_evaluator->install_post_filter(\&fix_for_polar_display);
	
     	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; 
					return $rh_ans unless $rh_ans->catch_error('EVAL');
					$rh_ans->{student_ans} = $rh_ans->{original_student_ans}. ' '. $rh_ans->{error_message};
					$rh_ans->clear_error('EVAL'); } );
     	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('SYNTAX'); } );
     	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('POLAR'); } );
     	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('CARTESIAN'); } );
     	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('COMPLEX'); } );
	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('STRING'); } );
     	$answer_evaluator;
}



# compares two complex numbers by comparing their real and imaginary parts
sub compare_cplx {
	my ($rh_ans, %options) = @_;
	my ($inVal,$PG_eval_errors,$PG_full_error_report) = PG_answer_eval($rh_ans->{student_ans});
	
	if ($PG_eval_errors) {
		$rh_ans->throw_error('EVAL','There is a syntax error in your answer');
		$rh_ans->{ans_message} = clean_up_error_msg($PG_eval_errors);
		 return $rh_ans;
	} else {
		$rh_ans->{student_ans} = prfmt($inVal,$options{format});
	}
	
	$inVal = cplx($inVal,0) unless ref($inVal) =~/Complex/;
	my $permitted_error_Re;
	my $permitted_error_Im;
	if ($rh_ans->{tolType} eq 'absolute')	{
		$permitted_error_Re = $rh_ans->{tolerance};
		$permitted_error_Im = $rh_ans->{tolerance};
	}
	elsif ( abs($rh_ans->{correct_ans}) <= $options{zeroLevel}) {
			$permitted_error_Re = $options{zeroLevelTol};  ## want $tol to be non zero
			$permitted_error_Im = $options{zeroLevelTol};  ## want $tol to be non zero
	}
	else {
		$permitted_error_Re =  abs($rh_ans->{tolerance}*$rh_ans->{correct_ans}->Complex::Re);
		$permitted_error_Im =  abs($rh_ans->{tolerance}*$rh_ans->{correct_ans}->Complex::Im);
	}
	
	$rh_ans->{score} = 1 if ( abs( $rh_ans->{correct_ans}->Complex::Re - $inVal->Complex::Re) <=
	$permitted_error_Re && abs($rh_ans->{correct_ans}->Complex::Im - $inVal->Complex::Im )<= $permitted_error_Im  );
	
	$rh_ans;
}

=head4 multi_cmp


	Checks a comma separated string of  items against an array of evaluators.
	For example this is useful for checking all of the complex roots of an equation.
	Each student answer must be evaluated as correct by a DISTINCT answer evalutor.
	
	This answer checker will only work reliably if each answer checker corresponds
	to a distinct correct answer.  For example if one answer checker requires
	any positive number, and the second requires the answer 1, then 1,2 might
	be judged incorrect since 1, satisifes the first answer checker, but 2 doesn't
	satisfy the second.  2,1 would work however. Avoid this type of use!!
	
	Including backtracking to fit the answers as best possible to each answer evaluator
	in the best possible way, is beyond the ambitions of this evaluator.


=cut 

sub multi_cmp {
	my $ra_answer_evaluators = shift;  # array of evaluators
	my %options = @_;
	my @answer_evaluators = @{$ra_answer_evaluators};
	my $backup_ans_eval = $answer_evaluators[0];
	my $multi_ans_evaluator = new AnswerEvaluator;
	$multi_ans_evaluator->install_evaluator( sub { 
		my $rh_ans = shift;
		my @student_answers = split/\s*,\s*/,$rh_ans->{student_ans};
		my @evaluated_ans_hashes = ();
		for ( my $j=0; $j<@student_answers; $j++ ) {
			# find an answer evaluator which marks this answer correct.
			my $student_ans = $student_answers[$j];
			my $temp_hash;
			for ( my $i=0; $i<@answer_evaluators; $i++ ) {
				my $evaluator = $answer_evaluators[$i];
				$temp_hash = new AnswerHash; # make a copy of the answer hash resulting from the evaluation
				%$temp_hash = %{$evaluator->evaluate($student_ans)}; 
				if (($temp_hash->{score} == 1)) {
				    # save evaluated answer
				    push @evaluated_ans_hashes, $temp_hash;
					# remove answer evaluator and check the next answer
					splice(@answer_evaluators,$i,1);
					last;
				}
			} 
			# if we exit the loop without finding a correct evaluation:
			# make sure every answer is evaluated, even extra answers for which 
			# there will be no answer evaluators left.
			if (not defined($temp_hash) ) { # make sure every answer is evaluated, even extra answers.
				my $evaluator = $backup_ans_eval;
				$temp_hash = new AnswerHash; # make a copy of the answer hash resulting from the evaluation
				%$temp_hash = %{$evaluator->evaluate($student_ans)}; 
				$temp_hash->{score} =0;  # this was an extra answer -- clearly incorrect
				$temp_hash->{correct_ans} = "too many answers";
			}
			# now make sure that even  answers which 
			# don't never evaluate correctly are still recorded in the list
			if ( $temp_hash->{score} <1) {
				push @evaluated_ans_hashes, $temp_hash;
			}

				
		}
		# construct the final answer hash
		my $rh_ans_out = shift @evaluated_ans_hashes;
		while (@evaluated_ans_hashes) {
			my $temp_hash = shift @evaluated_ans_hashes;
			$rh_ans_out =$rh_ans_out->AND($temp_hash);
		}
		$rh_ans_out->{student_ans} = $rh_ans->{student_ans};
		$rh_ans_out->{score}=0 unless @{$ra_answer_evaluators} == @student_answers; # require the  correct number of answers
		$rh_ans_out;
	});
	$multi_ans_evaluator;
}
# sub multi_cmp_old{
# 	my $pointer = shift;  # array of evaluators
# 	my %options = @_;
# 	my @evals = @{$pointer};
# 	my $answer_evaluator = new AnswerEvaluator;
# 	$answer_evaluator->install_evaluator( sub { 
# 		my $rh_ans = shift;
# 		$rh_ans->{score} = 1;#in order to use AND below, score must be 1 
# 		$rh_ans->{preview_text_string} = "";#needs to be initialized to prevent warnings
# 		my @student_answers = split/,/,$rh_ans->{student_ans};
# 		foreach my $eval ( @evals ){
# 			my $temp_eval = new AnswerEvaluator;
# 			my $temp_hash = $temp_eval->ans_hash;
# 			$temp_hash->{preview_text_string} = "";#needs to be initialized to prevent warnings
# 			#FIXME  I believe there is a logic problem here.
# 			# If each answer entered is judged correct by ONE answer evaluator
# 			# then the answer is correct, but for example if you enter a correct
# 			# root to an equation twice each answer will be judged correct and
# 			# and the whole question correct, even though the answer omits
# 			# the second root.
# 			foreach my $temp ( @student_answers ){
# 				$eval->evaluate($temp);
# 				$temp = $eval->ans_hash->{student_ans} unless $eval->ans_hash->{student_ans}=~ /you/i;
# 				$temp_hash = $temp_hash->OR( $eval->ans_hash );
# 				if( $eval->ans_hash->{score} == 1){ last; }
# 			}
# 			$rh_ans = $rh_ans->AND( $temp_hash );
# 		}
# 	#$rh_ans->{correct_ans} =~ s/No correct answer specified (OR|AND) //g;
# 	$rh_ans->{student_ans} = "";
# 	foreach( @student_answers ){ $rh_ans->{student_ans} .= "$_, "; }
# 	$rh_ans->{student_ans} =~ s/, \Z//;
# 	if( scalar(@evals) != scalar(@student_answers) ){ $rh_ans->{score} = 0; }#wrong number of answers makes answer wrong
# 	$rh_ans; });
# 	$answer_evaluator;
# }
# this does not seem to be in use, so I'm commenting it out.  Mike Gage 6/27/05
# sub mult_cmp{
# 	my $answer = shift;
# 	my @answers = @{$answer} if ref($answer) eq 'ARRAY';
# 	my %mult_params = @_;
# 	my @keys = qw ( tolerance tolType format mode zeroLevel zeroLevelTol debug );
# 	my @correctVal;
# 	my $formattedCorrectAnswer;
# 	my @correct_num_answer;
# 	my ($PG_eval_errors,$PG_full_error_report);
# 	assign_option_aliases( \%mult_params,
# 		'reltol'    =>      'relTol',
# 	);
#     set_default_options(\%mult_params,
# 		'tolType'       =>  (defined($mult_params{tol}) ) ? 'absolute' : 'relative',
# 			# default mode should be relative, to obtain this tol must not be defined
# 		'tolerance'     =>  $main::numAbsTolDefault, 
# 		'relTol'        =>  $main::numRelPercentTolDefault,
# 		'zeroLevel'     =>  $main::numZeroLevelDefault,
# 		'zeroLevelTol'  =>  $main::numZeroLevelTolDefault,
# 		'format'        =>  $main::numFormatDefault,
# 		'debug'         =>      0,
# 		'mode'          =>  'std',
# 		'compare'       =>  'num',
#     );
# 	my $format		=	$mult_params{'format'};
# 	my $mode		=	$mult_params{'mode'};
# 	
# 	
# 	if( $mult_params{tolType} eq 'relative' ) {
# 		$mult_params{'tolerance'} = .01*$mult_params{'relTol'};
# 	}
# 	
# 	if( $mult_params{ 'compare' } eq 'cplx' ){
# 		foreach( @answers )
# 		{
# 			$_ = cplx( $_, 0 ) unless ref($_) =~/Complex/;
# 		}
# 	}
# 	
# 	my $corrAnswerIsString = 0;
# 	
# 	for( my $k = 0; $k < @answers; $k++ ){
# 	if (defined($mult_params{strings}) && $mult_params{strings}) {
# 		my $legalString	= '';
# 		my @legalStrings = @{$mult_params{strings}};
# 		$correct_num_answer[$k] = $answers[$k];
# 		$formattedCorrectAnswer .= $answers[$k] . ",";
# 		foreach	$legalString (@legalStrings) {
# 			if ( uc($answers[$k]) eq uc($legalString) ) {
# 				$corrAnswerIsString	= 1;
# 				
# 				last;
# 			}
# 		}		## at	this point $corrAnswerIsString = 0 iff correct answer is numeric
# 	} else {
# 		$correct_num_answer[$k] = $answers[$k];
#   		$formattedCorrectAnswer .= prfmt( $answers[$k], $mult_params{'format'} ) . ", ";
# 	}
# 	$correct_num_answer[$k] = math_constants($correct_num_answer[$k]);
# 	my $PGanswerMessage = '';
# 	
# 	
# 	if (defined($correct_num_answer[$k]) && $correct_num_answer[$k] =~ /\S/ && $corrAnswerIsString == 0 )	{
# 			($correctVal[$k], $PG_eval_errors,$PG_full_error_report) =
# 			PG_answer_eval($correct_num_answer[$k]);
# 	} else { # case of a string answer
# 		$PG_eval_errors	= '	';
# 		$correctVal[$k] = $answers[$k];
# 	}
# 	
# 	#if ( ($PG_eval_errors && $corrAnswerIsString == 0) or ((not is_a_number($correctVal[$k])) && $corrAnswerIsString == 0)) {
# 				##error message from eval or above
# 		#warn "Error in 'correct' answer: $PG_eval_errors<br>
# 		      #The answer $answers[$k] evaluates to $correctVal[$k], 
# 		      #which cannot be interpreted as a number.  ";
# 		
# 	#}
# 	########################################################################
# 	$correctVal[$k] = $correct_num_answer[$k];
# 	}
# 	$formattedCorrectAnswer =~ s/, \Z//;	
# 	
# 	#construct the answer evaluator 
# 	
#     	my $answer_evaluator = new AnswerEvaluator; 
# 
# 	
#     	$answer_evaluator->{debug} = $mult_params{debug};
#     	$answer_evaluator->ans_hash( 	 
#     						correct_ans 			=> 	[@correctVal],
#     					 	type				=>	"${mode}_number",
#     					 	tolerance			=>	$mult_params{tolerance},
# 					 	tolType				=> 	'absolute', #	$mult_params{tolType},
# 					 	original_correct_ans		=>	$formattedCorrectAnswer,
#      					 	answerIsString			=>	$corrAnswerIsString,
# 						answer_form			=>	'cartesian',
#      	);
#     	my ($in, $formattedSubmittedAnswer);
# 		$answer_evaluator->install_pre_filter(sub {my $rh_ans = shift; 
# 		$rh_ans->{original_student_ans} = $rh_ans->{student_ans}; $rh_ans;}
# 	);
# 	if (defined($mult_params{strings}) && $mult_params{strings}) {
# 			$answer_evaluator->install_pre_filter(\&check_strings, %mult_params);
# 	}
# 	
# 	$answer_evaluator -> install_pre_filter( \&mult_prefilters, %mult_params );
# 	$answer_evaluator->install_pre_filter( sub{my $rh_ans = shift; $rh_ans->{original_student_ans} = $rh_ans->{student_ans};$rh_ans;});
# 	
# 	if ($corrAnswerIsString == 0 ){		# avoiding running compare_numbers when correct answer is a string.
# 		$answer_evaluator->install_evaluator(\&compare_mult, %mult_params);
# 	}
# 	  
# 	 	
# ###############################################################################
# # We'll leave these next lines out for now, so that the evaluated versions of the student's and professor's
# # can be displayed in the answer message.  This may still cause a few anomolies when strings are used
# #
# ###############################################################################
# 	$answer_evaluator->install_post_filter( sub{my $rh_ans = shift; $rh_ans->{student_ans} = $rh_ans->{original_student_ans};$rh_ans;});
# 	$answer_evaluator->install_post_filter(\&fix_answers_for_display);
# 	$answer_evaluator->install_post_filter(\&fix_for_polar_display);
# 	
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; 
# 					return $rh_ans unless $rh_ans->catch_error('EVAL');
# 					$rh_ans->{student_ans} = $rh_ans->{original_student_ans}. ' '. $rh_ans->{error_message};
# 					$rh_ans->clear_error('EVAL'); } );
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('SYNTAX'); } );
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('POLAR'); } );
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('CARTESIAN'); } );
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('COMPLEX'); } );
# 	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('STRING'); } );
#      	$answer_evaluator;
# }

# sub mult_prefilters{
# 	my ($rh_ans, %options) = @_;
# 	my @student_answers = split/,/,$rh_ans->{student_ans};
# 	foreach( @student_answers ){
# 		$rh_ans->{student_ans} = $_;
# 		$rh_ans = &check_syntax( $rh_ans );
# 		$rh_ans = &math_constants( $rh_ans );
# 		if( $options{compare} eq 'cplx' ){
# 			$rh_ans = &cplx_constants( $rh_ans );
# 			#$rh_ans = &check_for_polar( $rh_ans );
# 		}
# 		if ( $options{mode} eq 'std')	{
# 				# do nothing	
# 		} elsif ($options{mode} eq 'strict_polar') {
# 			$rh_ans = &is_a_polar( $rh_ans );
# 		} elsif ($options{mode} eq 'strict_num_cartesian') {
# 			$rh_ans = &is_a_numeric_cartesian( $rh_ans );
# 		} elsif ($options{mode} eq 'strict_num_polar') {
# 			$rh_ans = &is_a_numeric_polar( $rh_ans );
# 		} elsif ($options{mode} eq 'strict') {
# 			$rh_ans = &is_a_numeric_complex( $rh_ans );
# 		} elsif ($options{mode} eq 'arith') {
# 			$rh_ans = &is_an_arithmetic_expression( $rh_ans );
# 		} elsif ($options{mode} eq 'frac') {
# 			$rh_ans = &is_a_fraction( $rh_ans );
# 
# 		} else {	
# 			#$PGanswerMessage = 'Tell your professor	that there is an error in his or her answer mechanism. No mode was specified.';
# 			#$formattedSubmittedAnswer =	$in;
# 		}
# 		$_ = $rh_ans->{student_ans};
# 	}
# 	my $ans_string;
# 	foreach( @student_answers )
# 	{
# 		$ans_string .= ", $_";
# 	}	
# 	$ans_string =~ s/\A,//;
# 	$rh_ans->{student_ans} = $ans_string;
# 	$rh_ans;
# }

# sub polar{
#  	my $z = shift;
#  	my %options = @_;
#     my $r = rho($z);
#     my $theta = $z->theta;
#     my $r_format = ':%0.3f';
#     my $theta_format = ':%0.3f';
#     $r_format=":" . $options{r_format} if defined($options{r_format});
#     $theta_format = ":" . $options{theta_format} if defined($options{theta_format});
#     "{$r$r_format} e^{i {$theta$theta_format}}";
# 
# }

# compares two complex numbers by comparing their real and imaginary parts
# sub compare_mult {
# 	my ($rh_ans, %options) = @_;
# 	my @student_answers = split/,/,$rh_ans->{student_ans};
# 	my @correct_answers = @{$rh_ans->{correct_ans}};
# 	my $one_correct = 1/@correct_answers;
# 	my $temp_score = 0;
# 	foreach( @correct_answers ){
# 		$rh_ans->{correct_ans} = $_;
# 		foreach( @student_answers ){
# 			$rh_ans->{student_ans} = $_;
# 			if( $options{compare} eq 'cplx' ){
# 				$rh_ans = &compare_cplx( $rh_ans, %options);
# 			}else{
# 				$rh_ans = &compare_numbers( $rh_ans, %options);
# 			}
# 			if( $rh_ans->{score} == 1 )
# 			{
# 				$temp_score += $one_correct;
# 				$rh_ans->{score} = 0;
# 				last;
# 			}
# 		}
# 	}
# 	$rh_ans->{score} = $temp_score;
# 	$rh_ans;
# 	
# }



# Output is text displaying the complex numver in "e to the i theta" form. The
# formats for the argument theta is determined by the option C<theta_format> and the
# format for the modulus is determined by the C<r_format> option.

#this basically just checks for "e^" which unfortunately will show something like (e^4)*i as a polar, this should be changed
sub check_for_polar{

	my($in,%options) = @_;
	my $rh_ans;
	my $process_ans_hash = ( ref( $in ) eq 'AnswerHash' ) ? 1 : 0 ;
	if ($process_ans_hash) {
		$rh_ans = $in;
		$in = $rh_ans->{student_ans};
	} 
	# The code fragment above allows this filter to be used when the input is simply a string
	# as well as when the input is an AnswerHash, and options.
	if( $in =~ /2.71828182845905\*\*/ ){
	$rh_ans->{answer_form} = 'polar';
	}
	$rh_ans;
}



sub cplx_constants {
	my($in,%options) = @_;
	my $rh_ans;
	my $process_ans_hash = ( ref( $in ) eq 'AnswerHash' ) ? 1 : 0 ;
	if ($process_ans_hash) {
		$rh_ans = $in;
		$in = $rh_ans->{student_ans};
	} 
	# The code fragment above allows this filter to be used when the input is simply a string
	# as well as when the input is an AnswerHash, and options.
	$in =~ s/\bi\b/(i)/g;  #try to keep -i being recognized as a file reference
                                                           # and recognized as a function whose output is an imaginary number
                                                             
	if ($process_ans_hash)   {
    	$rh_ans->{student_ans}=$in;
    	return $rh_ans;
    } else {
		return $in;
	}
}

## allows only for numbers of the form a+bi and ae^(bi), where a and b are strict numbers
sub is_a_numeric_complex {
	my ($num,%options) =	@_;
	my $process_ans_hash = ( ref( $num ) eq 'AnswerHash' ) ? 1 : 0 ;
	my ($rh_ans);
	if ($process_ans_hash) {
		$rh_ans = $num;
		$num = $rh_ans->{student_ans};
	}
	
	my $is_a_number	= 0;
	return $is_a_number	unless defined($num);
	$num =~	s/^\s*//; ## remove	initial	spaces
	$num =~	s/\s*$//; ## remove	trailing spaces
	
	if ($num =~

/^($number[+,-]?($number\*\(i\)|\(i\)|\(i\)\*$number)|($number\*\(i\)|-?\(i\)|-?\(i\)\*$number)([+,-]$number)?|($number\*)?2.71828182845905\*\*\(($number\*\(i\)|\(i\)\*$number|i|-\(i\))\)|$number)$/){
		$is_a_number = 1;
	}
	
	if ($process_ans_hash)   {
    		if ($is_a_number == 1 ) {
    			$rh_ans->{student_ans}=$num;
    			return $rh_ans;
    		} else {
    			$rh_ans->{student_ans} = "Incorrect number format:  You	must enter a numeric complex, e.g. a+bi
			or a*e^(bi)";
    			$rh_ans->throw_error('COMPLEX', 'You must enter a number, e.g. -6, 5.3, or 6.12E-3');
    			return $rh_ans;
    		}
	} else {
		return $is_a_number;
	}
}

## allows only for the form a + bi, where a and b are strict numbers
sub is_a_numeric_cartesian {
	my ($num,%options) =	@_;
	my $process_ans_hash = ( ref( $num ) eq 'AnswerHash' ) ? 1 : 0 ;
	my ($rh_ans);
	if ($process_ans_hash) {
		$rh_ans = $num;
		$num = $rh_ans->{student_ans};
	}
	
	my $is_a_number	= 0;
	return $is_a_number	unless defined($num);
	$num =~	s/^\s*//; ## remove	initial	spaces
	$num =~	s/\s*$//; ## remove	trailing spaces
	
	if ($num =~

/^($number[+,-]?($number\*\(i\)|\(i\)|\(i\)\*$number)|($number\*\(i\)|-?\(i\)|-?\(i\)\*$number)([+,-]$number)?|$number)$/){
		$is_a_number = 1;
	}
	
	if ($process_ans_hash)   {
    		if ($is_a_number == 1 ) {
    			$rh_ans->{student_ans}=$num;
    			return $rh_ans;
    		} else {
    			$rh_ans->{student_ans} = "Incorrect number format:  You	must enter a numeric cartesian, e.g. a+bi";
    			$rh_ans->throw_error('CARTESIAN', 'You must enter a number, e.g. -6, 5.3, or 6.12E-3');
    			return $rh_ans;
    		}
	} else {
		return $is_a_number;
	}
}

## allows only for the form ae^(bi), where a and b are strict numbers
sub is_a_numeric_polar {
	my ($num,%options) =	@_;
	my $process_ans_hash = ( ref( $num ) eq 'AnswerHash' ) ? 1 : 0 ;
	my ($rh_ans);
	if ($process_ans_hash) {
		$rh_ans = $num;
		$num = $rh_ans->{student_ans};
	}
	
	my $is_a_number	= 0;
	return $is_a_number	unless defined($num);
	$num =~	s/^\s*//; ## remove	initial	spaces
	$num =~	s/\s*$//; ## remove	trailing spaces
	if ($num =~
	/^($number|($number\*)?2.71828182845905\*\*\(($number\*\(i\)|\(i\)\*$number|i|-\(i\))\))$/){
		$is_a_number = 1;
	}
	
	if ($process_ans_hash)   {
    		if ($is_a_number == 1 ) {
    			$rh_ans->{student_ans}=$num;
    			return $rh_ans;
    		} else {
    			$rh_ans->{student_ans} = "Incorrect number format:  You	must enter a numeric polar, e.g. a*e^(bi)";
    			$rh_ans->throw_error('POLAR', 'You must enter a number, e.g. -6, 5.3, or 6.12E-3');
    			return $rh_ans;
    		}
	} else {
		return $is_a_number;
	}
}

#this subroutine mearly captures what is before and after the "e**" it does not verify that the "i" is there, or in the
#exponent this must eventually be addresed
sub is_a_polar {
	my ($num,%options) =	@_;
	my $process_ans_hash = ( ref( $num ) eq 'AnswerHash' ) ? 1 : 0 ;
	my ($rh_ans);
	if ($process_ans_hash) {
		$rh_ans = $num;
		$num = $rh_ans->{student_ans};
	}
	
	my $is_a_number	= 0;
	return $is_a_number	unless defined($num);
	$num =~	s/^\s*//; ## remove	initial	spaces
	$num =~	s/\s*$//; ## remove	trailing spaces
	$num =~ /^(.*)\*2.71828182845905\*\*(.*)/;
	#warn "rho: ", $1;
	#warn "theta: ", $2;
	if( defined( $1 ) ){
		if( &single_term( $1 ) && &single_term( $2 ) )
		{
			$is_a_number = 1;
		}
	}
	if ($process_ans_hash)   {
    		if ($is_a_number == 1 ) {
    			$rh_ans->{student_ans}=$num;
    			return $rh_ans;
    		} else {
    			$rh_ans->{student_ans} = "Incorrect number format:  You	must enter a polar, e.g. a*e^(bi)";
    			$rh_ans->throw_error('POLAR', 'You must enter a number, e.g. -6, 5.3, or 6.12E-3');
    			return $rh_ans;
    		}
	} else {
		return $is_a_number;
	}
}

=head4 single_term()
	This subroutine takes in a string, which is a mathematical expresion, and determines whether or not
	it is a single term. This is accoplished using a stack. Open parenthesis pluses and minuses are all
	added onto the stack, and when a closed parenthesis is reached, the stack is popped untill the open
	parenthesis is found. If the original was a single term, the stack should be empty after
	evaluation. If there is anything left ( + or - ) then false is returned.
	Of course, the unary operator "-" must be handled... if it is a unary operator, and not a regular -
	the only place it could occur unambiguously without being surrounded by parenthesis, is the very
	first position. So that case is checked before the loop begins.
=cut

sub single_term{
	my $term = shift;
	my @stack;
	$term = reverse $term;
	if( length $term >= 1 )
	{
		my $temp = chop $term;
		if( $temp ne "-" ){ $term .= $temp; }
	}
	while( length $term >= 1 ){
		my $character = chop $term;
		if( $character eq "+" || $character eq "-" || $character eq "(" ){
			push @stack, $character;
		}elsif( $character eq ")" ){
			while( pop @stack ne "(" ){}
		}
		
	}
	if( scalar @stack == 0 ){ return 1;}else{ return 0;}
}

# changes default to display as a polar
sub fix_for_polar_display{
	my ($rh_ans, %options) = @_;
	if( ref( $rh_ans->{student_ans} ) =~ /Complex/ && $rh_ans->{answer_form} eq 'polar' ){
		$rh_ans->{student_ans}->display_format( 'polar');
		## these lines of code have the polar displayed as re^(theta) instead of [rho,theta]
		$rh_ans->{student_ans} =~ s/,/*e^\(/;
		$rh_ans->{student_ans} =~ s/\[//;
		$rh_ans->{student_ans} =~ s/\]/i\)/;
		}
	$rh_ans;
}

# this does not seem to be in use, so I'm commenting it out.  Mike Gage 6/27/05
# sub cplx_cmp2 {
# 	my $correctAnswer = shift;
# 	my %cplx_params = @_;
# 	my @keys = qw ( correctAnswer tolerance tolType format mode zeroLevel zeroLevelTol debug );
# 	assign_option_aliases( \%cplx_params,
#     						'reltol'    =>      'relTol',
# 	    );
#     	set_default_options(\%cplx_params,
#     					'tolType'		=>  (defined($cplx_params{tol}) ) ? 'absolute' : 'relative',
#     					# default mode should be relative, to obtain this tol must not be defined
# 					'tolerance'		=>	$main::numAbsTolDefault, 
# 	               			'relTol'		=>	$main::numRelPercentTolDefault,
# 					'zeroLevel'		=>	$main::numZeroLevelDefault,
# 					'zeroLevelTol'		=>	$main::numZeroLevelTolDefault,
# 					'format'		=>	$main::numFormatDefault,
# 					'debug'			=>  	0,
# 					'mode' 			=> 	'std',
# 
#     	);
# 	$correctAnswer = cplx($correctAnswer,0) unless ref($correctAnswer) =~/Complex/;
# 	my $format		=	$cplx_params{'format'};
# 	my $mode		=	$cplx_params{'mode'};
# 	
# 	if( $cplx_params{tolType} eq 'relative' ) {
# 		$cplx_params{'tolerance'} = .01*$cplx_params{'relTol'};
# 	}
# 	
# 	my $formattedCorrectAnswer;
# 	my $correct_num_answer;
# 	my $corrAnswerIsString = 0;
# 	
# 
# 	if (defined($cplx_params{strings}) && $cplx_params{strings}) {
# 		my $legalString	= '';
# 		my @legalStrings = @{$cplx_params{strings}};
# 		$correct_num_answer = $correctAnswer;
# 		$formattedCorrectAnswer = $correctAnswer;
# 		foreach	$legalString (@legalStrings) {
# 			if ( uc($correctAnswer) eq uc($legalString) ) {
# 				$corrAnswerIsString	= 1;
# 				
# 				last;
# 			}
# 		}		  ## at	this point $corrAnswerIsString = 0 iff correct answer is numeric
# 	} else {
# 		$correct_num_answer = $correctAnswer;
# 		$formattedCorrectAnswer = prfmt( $correctAnswer, $cplx_params{'format'} );
# 	}
# 	$correct_num_answer = math_constants($correct_num_answer);
# 	my $PGanswerMessage = '';
# 	
# 	my ($inVal,$correctVal,$PG_eval_errors,$PG_full_error_report);
# 	
# 	if (defined($correct_num_answer) && $correct_num_answer =~ /\S/ && $corrAnswerIsString == 0 )	{
# 			($correctVal, $PG_eval_errors,$PG_full_error_report) = PG_answer_eval($correct_num_answer);
# 	} else { # case of a string answer
# 		$PG_eval_errors	= '	';
# 		$correctVal = $correctAnswer;
# 	}
# 	
# 	if ( ($PG_eval_errors && $corrAnswerIsString == 0) or ((not is_a_number($correctVal)) && $corrAnswerIsString == 0)) {
# 				##error message from eval or above
# 		warn "Error in 'correct' answer: $PG_eval_errors<br>
# 		      The answer $correctAnswer evaluates to $correctVal, 
# 		      which cannot be interpreted as a number.  ";
# 		
# 	}
# 	########################################################################
# 	$correctVal = $correct_num_answer;#it took me two and a half hours to figure out that correctVal wasn't
# 	#getting the number properly
# 	#construct the answer evaluator 
#     	my $answer_evaluator = new AnswerEvaluator; 
# 
# 	
#     	$answer_evaluator->{debug} = $cplx_params{debug};
#     	$answer_evaluator->ans_hash( 	 
#     						correct_ans 			=> 	$correctVal,
#     					 	type				=>	"${mode}_number",
#     					 	tolerance			=>	$cplx_params{tolerance},
# 					 	tolType				=> 	'absolute', #	$cplx_params{tolType},
# 					 	original_correct_ans		=>	$formattedCorrectAnswer,
#      					 	answerIsString			=>	$corrAnswerIsString,
# 						answer_form			=>	'cartesian',
#      	);
#     	my ($in, $formattedSubmittedAnswer);
# 		$answer_evaluator->install_pre_filter(sub {my $rh_ans = shift; 
# 		$rh_ans->{original_student_ans} = $rh_ans->{student_ans}; $rh_ans;}
# 	);
# 	if (defined($cplx_params{strings}) && $cplx_params{strings}) {
# 			$answer_evaluator->install_pre_filter(\&check_strings, %cplx_params);
# 	}
# 	#$answer_evaluator->install_pre_filter(\&check_syntax);
# 		
# 	$answer_evaluator->install_pre_filter(\&math_constants);
# 	$answer_evaluator->install_pre_filter(\&cplx_constants);
# 	$answer_evaluator->install_pre_filter(\&check_for_polar);
# 	if ($mode eq 'std')	{
# 				# do nothing	
# 	} elsif ($mode eq 'strict_polar') {
# 		$answer_evaluator->install_pre_filter(\&is_a_polar);
# 	} elsif ($mode eq 'strict_num_cartesian') {
# 		$answer_evaluator->install_pre_filter(\&is_a_numeric_cartesian);
# 	} elsif ($mode eq 'strict_num_polar') {
# 		$answer_evaluator->install_pre_filter(\&is_a_numeric_polar);
# 	} elsif ($mode eq 'strict') {
# 		$answer_evaluator->install_pre_filter(\&is_a_numeric_complex);
# 	} elsif ($mode eq 'arith') {
# 			$answer_evaluator->install_pre_filter(\&is_an_arithmetic_expression);
# 		} elsif ($mode eq 'frac') {
# 			$answer_evaluator->install_pre_filter(\&is_a_fraction);
# 
# 		} else {	
# 			$PGanswerMessage = 'Tell your professor	that there is an error in his or her answer mechanism. No mode was specified.';
# 			$formattedSubmittedAnswer =	$in;
# 		}
# 	if ($corrAnswerIsString == 0 ){		# avoiding running compare_numbers when correct answer is a string.
# 		$answer_evaluator->install_evaluator(\&compare_cplx2, %cplx_params);
# 	}
# 	  
# 	 	
# ###############################################################################
# # We'll leave these next lines out for now, so that the evaluated versions of the student's and professor's
# # can be displayed in the answer message.  This may still cause a few anomolies when strings are used
# #
# ###############################################################################
# 
# 	$answer_evaluator->install_post_filter(\&fix_answers_for_display);
# 	$answer_evaluator->install_post_filter(\&fix_for_polar_display);
# 	
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; 
# 					return $rh_ans unless $rh_ans->catch_error('EVAL');
# 					$rh_ans->{student_ans} = $rh_ans->{original_student_ans}. ' '. $rh_ans->{error_message};
# 					$rh_ans->clear_error('EVAL'); } );
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('SYNTAX'); } );
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('POLAR'); } );
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('CARTESIAN'); } );
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('COMPLEX'); } );
# 	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('STRING'); } );
#      	$answer_evaluator;
# }


# compares two complex numbers by comparing their real and imaginary parts
# this does not seem to be in use, so I'm commenting it out.  Mike Gage 6/27/05
# sub compare_cplx2 {
# 	my ($rh_ans, %options) = @_;
# 	my @answers = split/,/,$rh_ans->{student_ans};
# 	foreach( @answers )
# 	{
# 	$rh_ans->{student_ans} = $_;
# 	$rh_ans = &check_syntax( $rh_ans );
# 	my ($inVal,$PG_eval_errors,$PG_full_error_report) = PG_answer_eval($rh_ans->{student_ans});
# 	
# 	if ($PG_eval_errors) {
# 		$rh_ans->throw_error('EVAL','There is a syntax error in your answer');
# 		$rh_ans->{ans_message} = clean_up_error_msg($PG_eval_errors);
# 		# return $rh_ans;
# 	} else {
# 		$rh_ans->{student_ans} = prfmt($inVal,$options{format});
# 	}
# 	
# 	$inVal = cplx($inVal,0) unless ref($inVal) =~/Complex/;
# 	my $permitted_error_Re;
# 	my $permitted_error_Im;
# 	if ($rh_ans->{tolType} eq 'absolute')	{
# 		$permitted_error_Re = $rh_ans->{tolerance};
# 		$permitted_error_Im = $rh_ans->{tolerance};
# 	}
# 	elsif ( abs($rh_ans->{correct_ans}) <= $options{zeroLevel}) {
# 			$permitted_error_Re = $options{zeroLevelTol};  ## want $tol to be non zero
# 			$permitted_error_Im = $options{zeroLevelTol};  ## want $tol to be non zero			
# 	}                                                                          			                                                                          			                                                                          			                                                                          			                                                                          			
# 	else {
# 		$permitted_error_Re =  abs($rh_ans->{tolerance}*$rh_ans->{correct_ans}->Complex::Re);
# 		$permitted_error_Im =  abs($rh_ans->{tolerance}*$rh_ans->{correct_ans}->Complex::Im);
# 		
# 	}
# 	
# 	$rh_ans->{score} = 1 if ( abs( $rh_ans->{correct_ans}->Complex::Re - $inVal->Complex::Re) <=
# 	$permitted_error_Re && abs($rh_ans->{correct_ans}->Complex::Im - $inVal->Complex::Im )<= $permitted_error_Im  );
# 	if( $rh_ans->{score} == 1 ){ return $rh_ans; }
# 	
# 	
# 	}
# 	$rh_ans;
# 	
# }

# this does not seem to be in use, so I'm commenting it out.  Mike Gage 6/27/05
# sub cplx_cmp_mult {
# 	my $correctAnswer = shift;
# 	my %cplx_params = @_;
# 	my @keys = qw ( correctAnswer tolerance tolType format mode zeroLevel zeroLevelTol debug );
# 	assign_option_aliases( \%cplx_params,
#     			'reltol'        =>      'relTol',
# 	);
# 	set_default_options(\%cplx_params,
# 				'tolType'		=>  (defined($cplx_params{tol}) ) ? 'absolute' : 'relative',
# 					# default mode should be relative, to obtain this tol must not be defined
# 				'tolerance'		=>	$main::numAbsTolDefault, 
# 						'relTol'		=>	$main::numRelPercentTolDefault,
# 				'zeroLevel'		=>	$main::numZeroLevelDefault,
# 				'zeroLevelTol'		=>	$main::numZeroLevelTolDefault,
# 				'format'		=>	$main::numFormatDefault,
# 				'debug'			=>  	0,
# 				'mode' 			=> 	'std',
# 
# 	);
# 	$correctAnswer = cplx($correctAnswer,0) unless ref($correctAnswer) =~/Complex/;
# 	my $format		=	$cplx_params{'format'};
# 	my $mode		=	$cplx_params{'mode'};
# 	
# 	if( $cplx_params{tolType} eq 'relative' ) {
# 		$cplx_params{'tolerance'} = .01*$cplx_params{'relTol'};
# 	}
# 	
# 	my $formattedCorrectAnswer;
# 	my $correct_num_answer;
# 	my $corrAnswerIsString = 0;
# 	
# 
# 	if (defined($cplx_params{strings}) && $cplx_params{strings}) {
# 		my $legalString	= '';
# 		my @legalStrings = @{$cplx_params{strings}};
# 		$correct_num_answer = $correctAnswer;
# 		$formattedCorrectAnswer = $correctAnswer;
# 		foreach	$legalString (@legalStrings) {
# 			if ( uc($correctAnswer) eq uc($legalString) ) {
# 				$corrAnswerIsString	= 1;
# 				
# 				last;
# 			}
# 		}		  ## at	this point $corrAnswerIsString = 0 iff correct answer is numeric
# 	} else {
# 		$correct_num_answer = $correctAnswer;
# 		$formattedCorrectAnswer = prfmt( $correctAnswer, $cplx_params{'format'} );
# 	}
# 	$correct_num_answer = math_constants($correct_num_answer);
# 	my $PGanswerMessage = '';
# 	
# 	my ($inVal,$correctVal,$PG_eval_errors,$PG_full_error_report);
# 	
# 	if (defined($correct_num_answer) && $correct_num_answer =~ /\S/ && $corrAnswerIsString == 0 )	{
# 			($correctVal, $PG_eval_errors,$PG_full_error_report) = PG_answer_eval($correct_num_answer);
# 	} else { # case of a string answer
# 		$PG_eval_errors	= '	';
# 		$correctVal = $correctAnswer;
# 	}
# 	
# 	if ( ($PG_eval_errors && $corrAnswerIsString == 0) or ((not is_a_number($correctVal)) && $corrAnswerIsString == 0)) {
# 				##error message from eval or above
# 		warn "Error in 'correct' answer: $PG_eval_errors<br>
# 		      The answer $correctAnswer evaluates to $correctVal, 
# 		      which cannot be interpreted as a number.  ";
# 		
# 	}
# 	########################################################################
# 	$correctVal = $correct_num_answer;#it took me two and a half hours to figure out that correctVal wasn't
# 	#getting the number properly
# 	#construct the answer evaluator 
# 	my $counter = 0;
# 	my $answer_evaluator = new AnswerEvaluator;
# 	
# 	my $number;
# 	$answer_evaluator->install_pre_filter( sub{ my $rh_ans = shift; my @temp =
# 	split/,/,$rh_ans->{student_ans}; $number = @temp; warn "this number ", $number; $rh_ans;});
# 	warn "number ", $number;
# 	while( $counter < 4 )
# 	{
# 	$answer_evaluator = &answer_mult( $correctVal, $mode, $formattedCorrectAnswer,
# 	$corrAnswerIsString, $counter, %cplx_params );
# 	warn "answer_evaluator ", $answer_evaluator;
# 	$answer_evaluator->install_evaluator( sub { my $rh_ans = shift; warn "score ", $rh_ans->{score};
# 	$rh_ans;});
# 	$counter += 1;
# 	}
# 	
# 	$answer_evaluator;
# 
# }

# this does not seem to be in use, so I'm commenting it out.  Mike Gage 6/27/05
# sub answer_mult{
# 	my $correctVal = shift;
# 	my $mode = shift;
# 	my $formattedCorrectAnswer = shift;
# 	my $corrAnswerIsString = shift;
# 	my $counter = shift;
# 	warn "counter ", $counter;
# 	
# 	my %cplx_params = @_;
#     	my $answer_evaluator = new AnswerEvaluator; 
# 
# 	
#     	$answer_evaluator->{debug} = $cplx_params{debug};
#     	$answer_evaluator->ans_hash( 	 
#     						correct_ans 			=> 	$correctVal,
#     					 	type				=>	"${mode}_number",
#     					 	tolerance			=>	$cplx_params{tolerance},
# 					 	tolType				=> 	'absolute', #	$cplx_params{tolType},
# 					 	original_correct_ans		=>	$formattedCorrectAnswer,
#      					 	answerIsString			=>	$corrAnswerIsString,
# 						answer_form			=>	'cartesian',
#      	);
# 	$answer_evaluator->install_pre_filter(sub {
# 		my $rh_ans = shift; 
# 		$rh_ans->{original_student_ans} = $rh_ans->{student_ans}; 
# 		my @answers = split/,/,$rh_ans->{student_ans};
# 		$rh_ans -> {student_ans} = $answers[$counter];
# 		$rh_ans;
# 		}
# 	);
# 	if (defined($cplx_params{strings}) && $cplx_params{strings}) {
# 			$answer_evaluator->install_pre_filter(\&check_strings, %cplx_params);
# 	}
# 	$answer_evaluator->install_pre_filter(\&check_syntax);	
# 	$answer_evaluator->install_pre_filter(\&math_constants);
# 	$answer_evaluator->install_pre_filter(\&cplx_constants);
# 	$answer_evaluator->install_pre_filter(\&check_for_polar);
# 	if ($mode eq 'std')	{
# 				# do nothing	
# 	} elsif ($mode eq 'strict_polar') {
# 		$answer_evaluator->install_pre_filter(\&is_a_polar);
# 	} elsif ($mode eq 'strict_num_cartesian') {
# 		$answer_evaluator->install_pre_filter(\&is_a_numeric_cartesian);
# 	} elsif ($mode eq 'strict_num_polar') {
# 		$answer_evaluator->install_pre_filter(\&is_a_numeric_polar);
# 	} elsif ($mode eq 'strict') {
# 		$answer_evaluator->install_pre_filter(\&is_a_numeric_complex);
# 	} elsif ($mode eq 'arith') {
# 			$answer_evaluator->install_pre_filter(\&is_an_arithmetic_expression);
# 		} elsif ($mode eq 'frac') {
# 			$answer_evaluator->install_pre_filter(\&is_a_fraction);
# 
# 		} else {	
# 			#$PGanswerMessage = 'Tell your professor	that there is an error in his or her answer mechanism. No mode was specified.';
# 		}
# 	if ($corrAnswerIsString == 0 ){		# avoiding running compare_numbers when correct answer is a string.
# 		$answer_evaluator->install_evaluator(\&compare_cplx, %cplx_params);
# 	}
# 	  
# 	 	
# ###############################################################################
# # We'll leave these next lines out for now, so that the evaluated versions of the student's and professor's
# # can be displayed in the answer message.  This may still cause a few anomolies when strings are used
# #
# ###############################################################################
# 
# 	$answer_evaluator->install_post_filter(\&fix_answers_for_display);
# 	$answer_evaluator->install_post_filter(\&fix_for_polar_display);
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; 
# 					return $rh_ans unless $rh_ans->catch_error('EVAL');
# 					$rh_ans->{student_ans} = $rh_ans->{original_student_ans}. ' '. $rh_ans->{error_message};
# 					$rh_ans->clear_error('EVAL'); } );
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('SYNTAX'); } );
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('POLAR'); } );
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('CARTESIAN'); } );
#      	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; $rh_ans->clear_error('COMPLEX'); } );
# 	$answer_evaluator->install_post_filter(sub {my $rh_ans = shift; warn "ans hash", $rh_ans->clear_error('STRING'); } );
# 	$answer_evaluator;
# }
# 


1;
