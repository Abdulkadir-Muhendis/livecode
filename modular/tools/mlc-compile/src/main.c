#include <stdio.h>
#include <string.h>

#include "literal.h"
#include "position.h"
#include "literal.h"
#include "report.h"

extern void ROOT(void);

static int s_is_bootstrap = 0;

int IsBootstrapCompile(void)
{
    return s_is_bootstrap;
}

void bootstrap_main(int argc, char *argv[])
{
    // If there is no filename, error.
    if (argc == 0)
    {
        fprintf(stderr, "Invalid arguments\n");
        return 1;
    }
    
    s_is_bootstrap = 1;
    
    for(int i = 0; i < argc; i++)
        AddFile(argv[i]);
    
    if (MoveToNextFile())
        ROOT();
    
    /*
    // Get the filename.
    const char *t_in_file;
    t_in_file = argv[0];
    
    // Compute the output filename.
    const char *t_in_leaf;
    t_in_leaf = strrchr(t_in_file, '/');
    if (t_in_leaf == NULL)
        t_in_leaf = t_in_file;
    
    char t_out_file[256];
    sprintf(t_out_file, "_G_/%s.g", t_in_leaf);
    extern FILE *yyout;
    yyout = fopen(t_out_file, "w");
    if (yyout == NULL)
    {
        fprintf(stderr, "Could not open output file '%s'\n", t_out_file);
        return 1;
    }
    
    extern FILE *yyin;
    yyin = fopen(t_in_file, "r");
    if (yyin == NULL)
    {
        fprintf(stderr, "Could not open file '%s'\n", argv[0]);
        return 1;
    }
    
    Run();
    
    return 0;*/
}

static void full_main(int argc, char *argv[])
{
    // If there is no filename, error.
    if (argc != 1)
    {
        fprintf(stderr, "Invalid arguments\n");
        return 1;
    }
    
    AddFile(argv[0]);
    if (MoveToNextFile())
        ROOT();
}

int main(int argc, char *argv[])
{
    // Skip command arg.
    argc -= 1;
    argv += 1;
    
    // Check for debug mode.
    if (argc > 1 && strcmp(argv[0], "-debug") == 0)
    {
        argc -= 1;
        argv += 1;
        
        extern int yydebug;
        yydebug = 1;
    }
    
    InitializePosition();
    InitializeLiterals();
    InitializeReports();
    InitializeScopes();
    
    // Check for bootstrap mode.
    if (argc > 1 && strcmp(argv[0], "-bootstrap") == 0)
        bootstrap_main(argc - 1, argv + 1);
    else
        full_main(argc, argv);
    
    int t_return_code;
    if (ErrorsDidOccur())
        t_return_code = 1;
    else
        t_return_code = 0;
    
    FinalizeScopes();
    FinalizeReports();
    FinalizeLiterals();
    FinalizePosition();
    
    return t_return_code;
    
    /*extern FILE *yyin;
    yyin = fopen(argv[0], "r");
    if (yyin == NULL)
    {
        fprintf(stderr, "Could not open file '%s'\n", argv[0]);
        return 1;
    }
    
    Run();
    
    return 0;*/
}
